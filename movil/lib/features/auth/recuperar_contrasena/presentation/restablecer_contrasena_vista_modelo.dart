import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recuperar_contrasena_repositorio.dart';

/// Estado de "Restablecer contraseña" (RF-06 CA-5 y CA-6).
class RestablecerContrasenaEstado {
  const RestablecerContrasenaEstado({this.cargando = false, this.error});

  final bool cargando;
  final ErrorRecuperacion? error;
}

class RestablecerContrasenaVistaModelo
    extends Notifier<RestablecerContrasenaEstado> {
  @override
  RestablecerContrasenaEstado build() => const RestablecerContrasenaEstado();

  /// Devuelve true si la contraseña cambió.
  ///
  /// Al terminar se cierra la sesión y el router lleva al login, así que
  /// esta pantalla puede desaparecer antes de que la llamada regrese: por
  /// eso el resultado se devuelve en vez de guardarse en el estado.
  Future<bool> restablecer(String nuevaContrasena) async {
    if (state.cargando) return false;

    final repositorio = ref.read(recuperarContrasenaRepositorioProvider);
    state = const RestablecerContrasenaEstado(cargando: true);
    try {
      await repositorio.restablecer(nuevaContrasena);
      return true;
    } on RecuperacionExcepcion catch (e) {
      if (ref.mounted) state = RestablecerContrasenaEstado(error: e.tipo);
      return false;
    }
  }

  Future<void> cancelar() =>
      ref.read(recuperarContrasenaRepositorioProvider).cancelar();
}

final restablecerContrasenaVistaModeloProvider = NotifierProvider.autoDispose<
    RestablecerContrasenaVistaModelo, RestablecerContrasenaEstado>(
  RestablecerContrasenaVistaModelo.new,
);
