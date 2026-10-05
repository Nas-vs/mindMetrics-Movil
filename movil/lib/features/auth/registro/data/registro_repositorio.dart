import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/datos_registro.dart';

/// Errores de dominio del registro. La UI solo conoce estos valores,
/// nunca las excepciones de Supabase.
enum ErrorRegistro { correoDuplicado, nicknameDuplicado, sinConexion, servidor }

class RegistroExcepcion implements Exception {
  const RegistroExcepcion(this.tipo);
  final ErrorRegistro tipo;

  @override
  String toString() => 'RegistroExcepcion($tipo)';
}

/// Capa de datos del RF-03: habla con Supabase y traduce sus errores.
class RegistroRepositorio {
  RegistroRepositorio(this._cliente);
  final SupabaseClient _cliente;

  /// RPC de Juliana. Se puede llamar sin sesión (grant a anon).
  Future<bool> nicknameDisponible(String nickname) async {
    final respuesta = await _cliente.rpc(
      'nickname_disponible',
      params: {'p_nickname': nickname.trim()},
    );
    return respuesta as bool;
  }

  Future<void> registrar(DatosRegistro datos) async {
    try {
      // 1. Validar el nickname ANTES del signUp. Si se dejara al trigger,
      //    el UNIQUE fallaría dentro de Auth y llegaría como un 500 genérico.
      if (!await nicknameDisponible(datos.nickname)) {
        throw const RegistroExcepcion(ErrorRegistro.nicknameDuplicado);
      }

      // 2. Crear la cuenta. Los triggers de RF-02 y RF-03 se ejecutan en la
      //    misma transacción: si alguno falla, no queda usuario a medias.
      final respuesta = await _cliente.auth.signUp(
        email: datos.correoNormalizado,
        password: datos.contrasena,
        data: datos.aMetadatos(),
      );

      // 3. Con confirmación de correo activa (RF-05), un correo ya registrado
      //    no lanza error: devuelve un usuario sin identidades.
      final identidades = respuesta.user?.identities;
      if (identidades != null && identidades.isEmpty) {
        throw const RegistroExcepcion(ErrorRegistro.correoDuplicado);
      }
    } on RegistroExcepcion {
      rethrow;
    } on AuthRetryableFetchException {
      throw const RegistroExcepcion(ErrorRegistro.sinConexion);
    } on SocketException {
      throw const RegistroExcepcion(ErrorRegistro.sinConexion);
    } on AuthException catch (e) {
      // Con confirmación desactivada (config local actual), un correo
      // repetido responde 422 con código 'user_already_exists'.
      final duplicado = e.code == 'user_already_exists' ||
          e.code == 'email_exists' ||
          e.statusCode == '422';
      throw RegistroExcepcion(
        duplicado ? ErrorRegistro.correoDuplicado : ErrorRegistro.servidor,
      );
    } on PostgrestException {
      throw const RegistroExcepcion(ErrorRegistro.servidor);
    } catch (_) {
      throw const RegistroExcepcion(ErrorRegistro.servidor);
    }
  }
}

/// Inyección de dependencias: en las pruebas se reemplaza por un fake con
/// `registroRepositorioProvider.overrideWithValue(...)`.
final registroRepositorioProvider = Provider<RegistroRepositorio>(
  (ref) => RegistroRepositorio(Supabase.instance.client),
);
