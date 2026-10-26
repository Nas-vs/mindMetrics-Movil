import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/verificacion_repositorio.dart';
import '../domain/argumentos_verificacion.dart';
import 'verificacion_estado.dart';

/// ViewModel (MVVM) del RF-05, con el mismo patrón que el registro.
///
/// Las reglas de intentos y reenvíos viven aquí (y no en el Back) porque
/// Supabase no limita cuántas veces se intenta un mismo código.
class VerificacionVistaModelo extends Notifier<VerificacionEstado> {
  /// CA-6 / CA-7: a los 3 códigos incorrectos se descarta la sesión.
  static const maxIntentos = 3;

  /// CA-5: máximo 3 reenvíos por sesión.
  static const maxReenvios = 3;

  /// CA-5: "Reenviar en 00:59". Coincide con `max_frequency = "60s"`.
  static const esperaReenvio = 60;

  /// Coincide con `otp_expiry = 600` del config.toml (10 minutos).
  static const vigenciaCodigo = Duration(minutes: 10);

  Timer? _temporizador;
  DateTime _codigoEnviadoEn = DateTime.now();

  @override
  VerificacionEstado build() {
    // Al abrir la pantalla, el código acaba de enviarse.
    _codigoEnviadoEn = DateTime.now();
    ref.onDispose(() => _temporizador?.cancel());
    _iniciarCuentaRegresiva();
    return const VerificacionEstado(segundosParaReenviar: esperaReenvio);
  }

  void _iniciarCuentaRegresiva() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      final restantes = state.segundosParaReenviar - 1;
      if (restantes <= 0) t.cancel();
      state = state.copiar(segundosParaReenviar: restantes < 0 ? 0 : restantes);
    });
  }

  int get intentosRestantes => maxIntentos - state.intentosFallidos;

  bool get puedeReenviar =>
      !state.reenviando &&
      !state.cargando &&
      state.segundosParaReenviar == 0 &&
      state.reenviosUsados < maxReenvios;

  Future<void> verificar(ArgumentosVerificacion argumentos, String codigo) async {
    if (state.cargando || state.exito || state.descartada) return;
    if (codigo.length != 6) return;

    // CA-7: código vencido → se vuelve al inicio de sesión.
    if (DateTime.now().difference(_codigoEnviadoEn) > vigenciaCodigo) {
      _temporizador?.cancel();
      state = state.copiar(descartada: true);
      return;
    }

    state = state.copiar(cargando: true);
    try {
      await ref
          .read(verificacionRepositorioProvider)
          .verificar(argumentos: argumentos, codigo: codigo);
      if (!ref.mounted) return;
      _temporizador?.cancel();
      state = state.copiar(cargando: false, exito: true);
    } on VerificacionExcepcion catch (e) {
      if (!ref.mounted) return;
      if (e.tipo == ErrorVerificacion.codigoIncorrecto) {
        final fallidos = state.intentosFallidos + 1;
        if (fallidos >= maxIntentos) _temporizador?.cancel();
        state = state.copiar(
          cargando: false,
          intentosFallidos: fallidos,
          descartada: fallidos >= maxIntentos,
        );
      } else {
        // Sin conexión o servidor: se conserva el código escrito.
        state = state.copiar(cargando: false, error: e.tipo);
      }
    }
  }

  Future<void> reenviar(ArgumentosVerificacion argumentos) async {
    if (!puedeReenviar) return;

    state = state.copiar(reenviando: true);
    try {
      await ref.read(verificacionRepositorioProvider).reenviar(argumentos);
      if (!ref.mounted) return;
      _codigoEnviadoEn = DateTime.now();
      state = state.copiar(
        reenviando: false,
        reenviosUsados: state.reenviosUsados + 1,
        segundosParaReenviar: esperaReenvio,
      );
      _iniciarCuentaRegresiva();
    } on VerificacionExcepcion catch (e) {
      if (!ref.mounted) return;
      state = state.copiar(reenviando: false, error: e.tipo);
    }
  }
}

/// autoDispose: el estado (y el temporizador) se descartan al salir.
final verificacionVistaModeloProvider =
    NotifierProvider.autoDispose<VerificacionVistaModelo, VerificacionEstado>(
  VerificacionVistaModelo.new,
);
