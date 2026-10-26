import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recuperar_contrasena_repositorio.dart';

/// Estado de "Recupera tu contraseña" (RF-06 CA-1 y CA-2).
class RecuperarContrasenaEstado {
  const RecuperarContrasenaEstado({
    this.cargando = false,
    this.enviado = false,
    this.error,
  });

  final bool cargando;

  /// true después de pedir el enlace: se muestra el aviso de CA-2.
  final bool enviado;

  final ErrorRecuperacion? error;
}

class RecuperarContrasenaVistaModelo
    extends Notifier<RecuperarContrasenaEstado> {
  @override
  RecuperarContrasenaEstado build() => const RecuperarContrasenaEstado();

  Future<void> solicitarEnlace(String correo) async {
    if (state.cargando) return;

    final enviadoAntes = state.enviado;
    state = RecuperarContrasenaEstado(cargando: true, enviado: enviadoAntes);
    try {
      await ref.read(recuperarContrasenaRepositorioProvider).solicitarEnlace(correo);
      if (!ref.mounted) return;
      state = const RecuperarContrasenaEstado(enviado: true);
    } on RecuperacionExcepcion catch (e) {
      if (!ref.mounted) return;
      state = RecuperarContrasenaEstado(enviado: enviadoAntes, error: e.tipo);
    }
  }
}

final recuperarContrasenaVistaModeloProvider = NotifierProvider.autoDispose<
    RecuperarContrasenaVistaModelo, RecuperarContrasenaEstado>(
  RecuperarContrasenaVistaModelo.new,
);
