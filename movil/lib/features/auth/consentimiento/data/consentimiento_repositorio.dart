import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/politica_privacidad.dart';

/// Errores de dominio al cargar el consentimiento informado (RF-02).
enum ErrorConsentimiento { sinConexion, servidor }

class ConsentimientoExcepcion implements Exception {
  const ConsentimientoExcepcion(this.tipo);
  final ErrorConsentimiento tipo;

  @override
  String toString() => 'ConsentimientoExcepcion($tipo)';
}

/// Capa de datos del RF-02: lee la política vigente desde `politicas_privacidad`.
class ConsentimientoRepositorio {
  ConsentimientoRepositorio(this._cliente);
  final SupabaseClient _cliente;

  Future<PoliticaPrivacidad> obtenerPoliticaVigente() async {
    try {
      final fila = await _cliente
          .from('politicas_privacidad')
          .select('version, titulo, contenido')
          .eq('vigente', true)
          .single();

      return PoliticaPrivacidad.desdeMapa(fila);
    } on SocketException {
      throw const ConsentimientoExcepcion(ErrorConsentimiento.sinConexion);
    } on TimeoutException {
      throw const ConsentimientoExcepcion(ErrorConsentimiento.sinConexion);
    } on PostgrestException {
      throw const ConsentimientoExcepcion(ErrorConsentimiento.servidor);
    } catch (e) {
      final texto = e.toString();
      if (texto.contains('SocketException') ||
          texto.contains('ClientException') ||
          texto.contains('Failed host lookup') ||
          texto.contains('Connection refused')) {
        throw const ConsentimientoExcepcion(ErrorConsentimiento.sinConexion);
      }
      throw const ConsentimientoExcepcion(ErrorConsentimiento.servidor);
    }
  }
}

/// Provider inyectable para pruebas (`overrideWithValue`).
final consentimientoRepositorioProvider = Provider<ConsentimientoRepositorio>(
  (ref) => ConsentimientoRepositorio(Supabase.instance.client),
);

//test
