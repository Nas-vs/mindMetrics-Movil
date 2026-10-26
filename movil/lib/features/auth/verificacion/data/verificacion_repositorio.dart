import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/seguridad/identificador_dispositivo.dart';
import '../domain/argumentos_verificacion.dart';

/// Errores de dominio de la verificación. La UI solo conoce estos valores.
enum ErrorVerificacion {
  /// Código equivocado o vencido (Supabase no distingue entre los dos).
  codigoIncorrecto,
  demasiadosCorreos,
  sinConexion,
  servidor,
}

class VerificacionExcepcion implements Exception {
  const VerificacionExcepcion(this.tipo);
  final ErrorVerificacion tipo;

  @override
  String toString() => 'VerificacionExcepcion($tipo)';
}

/// Capa de datos del RF-05.
///
/// - Registro: el código llega con la plantilla `confirmacion.html` y se
///   verifica con `OtpType.signup`.
/// - Inicio de sesión: la Edge Function `bloqueo-login` lo envía con
///   `signInWithOtp` (plantilla `codigo_acceso.html`) y se verifica con
///   `OtpType.email`.
/// En ambos casos, verificar crea la sesión en el celular.
class VerificacionRepositorio {
  VerificacionRepositorio(this._cliente, this._dispositivo);

  final SupabaseClient _cliente;
  final IdentificadorDispositivo _dispositivo;

  Future<void> verificar({
    required ArgumentosVerificacion argumentos,
    required String codigo,
  }) async {
    try {
      await _cliente.auth.verifyOTP(
        email: argumentos.correo,
        token: codigo,
        type: argumentos.motivo == MotivoVerificacion.registro
            ? OtpType.signup
            : OtpType.email,
      );
    } catch (e) {
      throw VerificacionExcepcion(_traducir(e));
    }

    // Ya verificó el código en este celular: queda como conocido para que
    // el próximo inicio de sesión no lo pida (RPC de Nasly, RF-04 CA-4).
    // Si falla, la sesión ya existe; solo se pedirá el código otra vez.
    try {
      await _cliente.rpc(
        'registrar_dispositivo',
        params: {'p_dispositivo_id': await _dispositivo.obtener()},
      );
    } catch (_) {}
  }

  /// RF-05 CA-5: "Reenviar código".
  Future<void> reenviar(ArgumentosVerificacion argumentos) async {
    try {
      if (argumentos.motivo == MotivoVerificacion.registro) {
        await _cliente.auth.resend(
          type: OtpType.signup,
          email: argumentos.correo,
        );
      } else {
        // Igual que hace la Edge Function: código a una cuenta existente.
        await _cliente.auth.signInWithOtp(
          email: argumentos.correo,
          shouldCreateUser: false,
        );
      }
    } catch (e) {
      throw VerificacionExcepcion(_traducir(e));
    }
  }

  static ErrorVerificacion _traducir(Object e) {
    if (e is AuthRetryableFetchException ||
        e is SocketException ||
        e is TimeoutException) {
      return ErrorVerificacion.sinConexion;
    }
    if (e is AuthException) {
      if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit') {
        return ErrorVerificacion.demasiadosCorreos;
      }
      if (e.code == 'otp_expired' ||
          e.statusCode == '400' ||
          e.statusCode == '401' ||
          e.statusCode == '403') {
        return ErrorVerificacion.codigoIncorrecto;
      }
      return ErrorVerificacion.servidor;
    }
    final texto = e.toString();
    if (texto.contains('SocketException') ||
        texto.contains('ClientException') ||
        texto.contains('Connection refused')) {
      return ErrorVerificacion.sinConexion;
    }
    return ErrorVerificacion.servidor;
  }
}

/// En las pruebas se reemplaza por un fake con `overrideWithValue(...)`.
final verificacionRepositorioProvider = Provider<VerificacionRepositorio>(
  (ref) => VerificacionRepositorio(
    Supabase.instance.client,
    ref.watch(identificadorDispositivoProvider),
  ),
);
