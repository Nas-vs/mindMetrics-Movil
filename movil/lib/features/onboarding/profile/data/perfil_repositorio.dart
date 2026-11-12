import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/perfil_usuario.dart';

/// Errores de dominio al consultar o editar el perfil (RF-23).
enum ErrorPerfil {
  nicknameOcupado,
  formatoInvalido,
  sinConexion,
  servidor,
  sesionRequerida,
}

class PerfilExcepcion implements Exception {
  const PerfilExcepcion(this.tipo, [this.mensaje]);
  final ErrorPerfil tipo;
  final String? mensaje;

  @override
  String toString() => 'PerfilExcepcion($tipo: $mensaje)';
}

/// Capa de datos del RF-23: consulta y edita la tabla `public.perfiles`.
class PerfilRepositorio {
  PerfilRepositorio([this._cliente]);

  final SupabaseClient? _cliente;

  /// CA-1: Lee los datos del usuario autenticado.
  Future<PerfilUsuario> obtenerPerfil() async {
    final cliente = _cliente;
    final usuario = cliente?.auth.currentUser;
    if (cliente == null || usuario == null) {
      throw const PerfilExcepcion(ErrorPerfil.sesionRequerida);
    }

    try {
      final fila = await cliente
          .from('perfiles')
          .select('id, nombre_completo, nickname, creado_en')
          .eq('id', usuario.id)
          .single();

      return PerfilUsuario.desdeSupabase(
        fila: fila,
        correo: usuario.email ?? '',
      );
    } on SocketException {
      throw const PerfilExcepcion(ErrorPerfil.sinConexion);
    } on TimeoutException {
      throw const PerfilExcepcion(ErrorPerfil.sinConexion);
    } on PostgrestException catch (e) {
      throw PerfilExcepcion(ErrorPerfil.servidor, e.message);
    } catch (e) {
      throw _traducirError(e);
    }
  }

  /// CA-2: Actualiza nombre y nickname del usuario.
  Future<PerfilUsuario> actualizarPerfil({
    required String nuevoNombre,
    required String nuevoNickname,
  }) async {
    final cliente = _cliente;
    final usuario = cliente?.auth.currentUser;
    if (cliente == null || usuario == null) {
      throw const PerfilExcepcion(ErrorPerfil.sesionRequerida);
    }

    final nombreLimpio = nuevoNombre.trim();
    final nicknameLimpio = nuevoNickname.trim();

    try {
      // 1. Ejecutar el UPDATE (el trigger de RF-23 normaliza y actualiza la fecha).
      final fila = await cliente
          .from('perfiles')
          .update({'nombre_completo': nombreLimpio, 'nickname': nicknameLimpio})
          .eq('id', usuario.id)
          .select('id, nombre_completo, nickname, creado_en')
          .single();

      // 2. Refrescar sesión para que app_metadata.nickname se actualice (RF-07).
      try {
        await cliente.auth.refreshSession();
      } catch (_) {}

      return PerfilUsuario.desdeSupabase(
        fila: fila,
        correo: usuario.email ?? '',
      );
    } on PostgrestException catch (e) {
      // Código PostgreSQL 23505: violación de unicidad (índice lower(nickname))
      if (e.code == '23505') {
        throw const PerfilExcepcion(
          ErrorPerfil.nicknameOcupado,
          'Este nickname ya está en uso por otro usuario.',
        );
      }
      throw PerfilExcepcion(ErrorPerfil.servidor, e.message);
    } on SocketException {
      throw const PerfilExcepcion(ErrorPerfil.sinConexion);
    } on TimeoutException {
      throw const PerfilExcepcion(ErrorPerfil.sinConexion);
    } catch (e) {
      throw _traducirError(e);
    }
  }

  PerfilExcepcion _traducirError(Object e) {
    if (e is SocketException || e is TimeoutException) {
      return const PerfilExcepcion(ErrorPerfil.sinConexion);
    }
    final texto = e.toString();
    if (texto.contains('SocketException') ||
        texto.contains('ClientException') ||
        texto.contains('Failed host lookup') ||
        texto.contains('Connection refused')) {
      return const PerfilExcepcion(ErrorPerfil.sinConexion);
    }
    return const PerfilExcepcion(ErrorPerfil.servidor);
  }
}

/// Provider inyectable con Riverpod para pruebas unitarias.
final perfilRepositorioProvider = Provider<PerfilRepositorio>(
  (ref) => PerfilRepositorio(Supabase.instance.client),
);
