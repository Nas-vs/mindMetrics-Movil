import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Errores de dominio de RF-06. La UI solo conoce estos valores.
enum ErrorRecuperacion {
  /// Se pidió otro enlace hace menos de 60 s (`max_frequency`).
  demasiadasSolicitudes,

  /// La nueva contraseña es igual a la anterior.
  mismaContrasena,

  /// Supabase rechazó la contraseña por no cumplir las reglas.
  contrasenaDebil,

  /// La sesión temporal del enlace ya no existe.
  sesionVencida,

  sinConexion,
  servidor,
}

class RecuperacionExcepcion implements Exception {
  const RecuperacionExcepcion(this.tipo);
  final ErrorRecuperacion tipo;

  @override
  String toString() => 'RecuperacionExcepcion($tipo)';
}

/// Capa de datos del RF-06 (Back de Samuel).
///
/// 1. [solicitarEnlace] envía el correo con la plantilla `recuperacion.html`.
///    El enlace vuelve a la app por `mindmetrics://restablecer-contrasena`
///    (debe estar en `additional_redirect_urls` del config.toml).
/// 2. Al tocar el enlace, supabase_flutter crea una sesión temporal y emite
///    `passwordRecovery` (lo escucha `EstadoRecuperacion`).
/// 3. [restablecer] cambia la contraseña, cierra todas las sesiones con la
///    RPC `cerrar_sesiones_recuperacion` (CA-6) y cierra la de este celular.
class RecuperarContrasenaRepositorio {
  RecuperarContrasenaRepositorio(this._cliente);

  static const urlRetorno = 'mindmetrics://restablecer-contrasena';

  final SupabaseClient _cliente;

  /// CA-2: no revela si el correo existe. Supabase responde igual en los
  /// dos casos, así que solo pueden fallar la red o el límite de envíos.
  Future<void> solicitarEnlace(String correo) async {
    try {
      await _cliente.auth.resetPasswordForEmail(
        correo.trim().toLowerCase(),
        redirectTo: urlRetorno,
      );
    } catch (e) {
      throw RecuperacionExcepcion(_traducir(e));
    }
  }

  Future<void> restablecer(String nuevaContrasena) async {
    try {
      await _cliente.auth.updateUser(UserAttributes(password: nuevaContrasena));
    } catch (e) {
      throw RecuperacionExcepcion(_traducir(e));
    }

    // CA-6: cerrar las sesiones de los demás celulares y olvidar los
    // dispositivos confiables. Si la RPC falla, se cierra todo con Auth.
    try {
      await _cliente.rpc('cerrar_sesiones_recuperacion');
    } catch (_) {
      try {
        await _cliente.auth.signOut(scope: SignOutScope.global);
      } catch (_) {}
    }

    // Y la de este celular: se vuelve a entrar con la contraseña nueva.
    // (La RPC ya borró la sesión en el servidor; el error de cerrarla allá
    // se ignora, pero la sesión local se borra siempre.)
    try {
      await _cliente.auth.signOut();
    } catch (_) {}
  }

  /// Cancelar en "Restablecer contraseña": descarta la sesión temporal.
  Future<void> cancelar() async {
    try {
      await _cliente.auth.signOut();
    } catch (_) {}
  }

  static ErrorRecuperacion _traducir(Object e) {
    if (e is AuthRetryableFetchException ||
        e is SocketException ||
        e is TimeoutException) {
      return ErrorRecuperacion.sinConexion;
    }
    if (e is AuthException) {
      if (e.code == 'same_password') return ErrorRecuperacion.mismaContrasena;
      if (e.code == 'weak_password') return ErrorRecuperacion.contrasenaDebil;
      if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit') {
        return ErrorRecuperacion.demasiadasSolicitudes;
      }
      if (e is AuthSessionMissingException ||
          e.code == 'session_not_found' ||
          e.statusCode == '401' ||
          e.statusCode == '403') {
        return ErrorRecuperacion.sesionVencida;
      }
      return ErrorRecuperacion.servidor;
    }
    final texto = e.toString();
    if (texto.contains('SocketException') ||
        texto.contains('ClientException') ||
        texto.contains('Connection refused')) {
      return ErrorRecuperacion.sinConexion;
    }
    return ErrorRecuperacion.servidor;
  }
}

/// En las pruebas se reemplaza por un fake con `overrideWithValue(...)`.
final recuperarContrasenaRepositorioProvider =
    Provider<RecuperarContrasenaRepositorio>(
  (ref) => RecuperarContrasenaRepositorio(Supabase.instance.client),
);
