import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inicio_sesion_repositorio.dart';
import 'inicio_sesion_estado.dart';

/// ViewModel (MVVM) del RF-04, con el mismo patrón que el registro.
class InicioSesionVistaModelo extends Notifier<InicioSesionEstado> {
  @override
  InicioSesionEstado build() => const InicioSesionEstado();

  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    if (state.cargando) return; // Evita el doble envío (CA-3).

    state = const InicioSesionEstado(cargando: true);
    try {
      final resultado = await ref
          .read(inicioSesionRepositorioProvider)
          .iniciarSesion(correo: correo, contrasena: contrasena);
      if (!ref.mounted) return; // La pantalla se cerró mientras esperaba.
      state = InicioSesionEstado(resultado: resultado);
    } on InicioSesionExcepcion catch (e) {
      if (!ref.mounted) return;
      state = InicioSesionEstado(error: e.tipo);
    }
  }
}

/// autoDispose: el estado se descarta al salir de la pantalla.
final inicioSesionVistaModeloProvider =
    NotifierProvider.autoDispose<InicioSesionVistaModelo, InicioSesionEstado>(
  InicioSesionVistaModelo.new,
);
