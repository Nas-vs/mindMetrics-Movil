import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/seguridad/identificador_dispositivo.dart';

/// Qué pasa después de un inicio de sesión con credenciales correctas.
enum ResultadoInicioSesion {
  /// Celular conocido: ya hay sesión (RF-04 CA-4).
  sesionIniciada,

  /// Celular nuevo: el Back envió un código al correo (RF-04 CA-5).
  requiereCodigo,

  /// La cuenta nunca verificó el correo: se reenvió el código del registro.
  requiereVerificarCorreo,
}

/// Errores de dominio del inicio de sesión. La UI solo conoce estos valores.
enum ErrorInicioSesion {
  credencialesInvalidas,
  bloqueado,
  demasiadosCorreos,
  sinConexion,
  servidor,
}

class InicioSesionExcepcion implements Exception {
  const InicioSesionExcepcion(this.tipo);
  final ErrorInicioSesion tipo;

  @override
  String toString() => 'InicioSesionExcepcion($tipo)';
}

/// Capa de datos del RF-04: habla con la Edge Function `bloqueo-login`
/// (Back de Nasly) y traduce sus respuestas.
///
/// Contrato de `bloqueo-login` (POST {correo, contrasena, dispositivo_id}):
///   200 {requiere_2fa: false, sesion: {...}} → celular conocido
///   200 {requiere_2fa: true}                 → código enviado al correo
///   401 credenciales_invalidas · 403 correo_no_verificado
///   423 bloqueado · 429 demasiados_correos · 400/500 servidor
class InicioSesionRepositorio {
  InicioSesionRepositorio(this._cliente, this._dispositivo);

  final SupabaseClient _cliente;
  final IdentificadorDispositivo _dispositivo;

  Future<ResultadoInicioSesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final correoNormalizado = correo.trim().toLowerCase();

    try {
      final respuesta = await _cliente.functions.invoke(
        'bloqueo-login',
        body: {
          'correo': correoNormalizado,
          'contrasena': contrasena,
          'dispositivo_id': await _dispositivo.obtener(),
        },
      );

      if (respuesta.status < 200 || respuesta.status >= 300) {
        return await _manejarError(respuesta.status, correoNormalizado);
      }

      final datos = respuesta.data;
      if (datos is! Map) {
        throw const InicioSesionExcepcion(ErrorInicioSesion.servidor);
      }

      if (datos['requiere_2fa'] == true) {
        return ResultadoInicioSesion.requiereCodigo;
      }

      // Celular conocido: la Edge Function devuelve la sesión; se le entrega
      // a supabase_flutter, que la guarda y avisa al router.
      final sesion = datos['sesion'];
      final refreshToken = sesion is Map ? sesion['refresh_token'] : null;
      if (refreshToken is! String) {
        throw const InicioSesionExcepcion(ErrorInicioSesion.servidor);
      }
      await _cliente.auth.setSession(refreshToken);
      return ResultadoInicioSesion.sesionIniciada;
    } on InicioSesionExcepcion {
      rethrow;
    } on FunctionException catch (e) {
      // functions.invoke lanza esta excepción cuando el estado no es 2xx.
      return _manejarError(e.status, correoNormalizado);
    } on AuthRetryableFetchException {
      throw const InicioSesionExcepcion(ErrorInicioSesion.sinConexion);
    } catch (e) {
      throw InicioSesionExcepcion(
        _esErrorDeRed(e) ? ErrorInicioSesion.sinConexion : ErrorInicioSesion.servidor,
      );
    }
  }

  Future<ResultadoInicioSesion> _manejarError(int estado, String correo) async {
    switch (estado) {
      case 401:
        throw const InicioSesionExcepcion(ErrorInicioSesion.credencialesInvalidas);
      case 423:
        throw const InicioSesionExcepcion(ErrorInicioSesion.bloqueado);
      case 429:
        throw const InicioSesionExcepcion(ErrorInicioSesion.demasiadosCorreos);
      case 403:
        // La cuenta existe pero no verificó el correo. La Edge Function no
        // envía código en este caso, así que se reenvía el del registro.
        try {
          await _cliente.auth.resend(type: OtpType.signup, email: correo);
        } on AuthException {
          // Si se pidió hace menos de 60 s (max_frequency), el código
          // anterior sigue sirviendo: se continúa igual.
        }
        return ResultadoInicioSesion.requiereVerificarCorreo;
      default:
        throw const InicioSesionExcepcion(ErrorInicioSesion.servidor);
    }
  }

  static bool _esErrorDeRed(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    // El paquete http envuelve los errores de red en ClientException.
    final texto = e.toString();
    return texto.contains('SocketException') ||
        texto.contains('ClientException') ||
        texto.contains('Failed host lookup') ||
        texto.contains('Connection refused');
  }
}

/// En las pruebas se reemplaza por un fake con `overrideWithValue(...)`.
final inicioSesionRepositorioProvider = Provider<InicioSesionRepositorio>(
  (ref) => InicioSesionRepositorio(
    Supabase.instance.client,
    ref.watch(identificadorDispositivoProvider),
  ),
);
