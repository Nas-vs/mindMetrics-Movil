import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/seguridad/identificador_dispositivo.dart';

/// Cierre de sesión (no tiene RF propio; se agregó en el menú lateral).
///
/// Además de cerrar la sesión de ESTE celular, lo quita de los dispositivos
/// confiables (RF-04/RF-05): al volver a entrar se pide el código otra vez.
class SesionRepositorio {
  SesionRepositorio(this._cliente, this._dispositivo);

  final SupabaseClient _cliente;
  final IdentificadorDispositivo _dispositivo;

  /// Nunca falla: aunque no haya internet, supabase_flutter borra primero
  /// la sesión local, avisa al router y este lleva al inicio de sesión.
  Future<void> cerrarSesion() async {
    // 1. Olvidar este celular. Va antes del signOut porque necesita la
    //    sesión: la política RLS "cada usuario borra sus dispositivos"
    //    (migración de RF-04/RF-05) solo deja borrar los propios.
    //    Sin internet no se puede borrar; ese celular seguiría siendo
    //    conocido, pero la sesión se cierra igual.
    try {
      final usuario = _cliente.auth.currentUser;
      if (usuario != null) {
        await _cliente
            .from('dispositivos_confiables')
            .delete()
            .eq('usuario_id', usuario.id)
            .eq('dispositivo_id', await _dispositivo.obtener());
      }
    } catch (_) {}

    // 2. Cerrar la sesión de este celular.
    try {
      await _cliente.auth.signOut();
    } catch (_) {}
  }
}

/// En las pruebas se reemplaza por un fake con `overrideWithValue(...)`.
final sesionRepositorioProvider = Provider<SesionRepositorio>(
  (ref) => SesionRepositorio(
    Supabase.instance.client,
    ref.watch(identificadorDispositivoProvider),
  ),
);
