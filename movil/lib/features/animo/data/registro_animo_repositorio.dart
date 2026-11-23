import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../recordatorio/data/almacen_clave_valor.dart';
import '../domain/registro_animo.dart';

/// Resultado de guardar: en el servidor o en la cola local (sin conexión).
enum ResultadoGuardado { sincronizado, pendienteSinConexion }

/// Alerta de bienestar de RF-08 CA-8 (`alerta_pendiente`).
class AlertaBienestar {
  const AlertaBienestar({required this.id, required this.motivo});
  final String id;

  /// 'riesgo_alto' | 'muy_bajo_seguido' | 'racha_baja'
  final String motivo;
}

/// Contrato del back de RF-08 (migraciones `20261026000000_rf08_registro_animo`
/// y `20261109150000_rf08_ca8_regla_alerta`).
abstract class RegistroAnimoRepositorio {
  Future<List<OpcionCatalogo>> emociones();
  Future<List<OpcionCatalogo>> factores();

  /// CA-3: el registro de hoy, si existe, para editarlo (uno por día).
  Future<RegistroAnimo?> registroDe(String fecha);

  /// Guarda primero en la cola local y luego intenta subirlo.
  Future<ResultadoGuardado> guardar(RegistroAnimo registro);

  /// Sube lo que quedó en la cola (al abrir la pantalla o al recuperar red).
  Future<void> sincronizarPendientes();

  Future<AlertaBienestar?> alertaPendiente();
  Future<void> marcarAlertaVista(String id);
}

class RegistroAnimoSupabase implements RegistroAnimoRepositorio {
  RegistroAnimoSupabase(this._db, this._almacen);

  final SupabaseClient _db;
  final AlmacenClaveValor _almacen;

  /// Cola sin conexión: un mapa fecha → registro. Si se edita dos veces sin
  /// red, solo queda la última versión del día (lo que pide CA-3).
  static const _claveCola = 'rf08_cola_pendiente';

  @override
  Future<List<OpcionCatalogo>> emociones() => _catalogo('emociones');

  @override
  Future<List<OpcionCatalogo>> factores() => _catalogo('factores');

  Future<List<OpcionCatalogo>> _catalogo(String tabla) async {
    final filas = await _db
        .from(tabla)
        .select('id, nombre')
        .eq('activo', true)
        .order('orden');
    return [
      for (final f in filas)
        OpcionCatalogo(id: (f['id'] as num).toInt(), nombre: f['nombre'] as String),
    ];
  }

  @override
  Future<RegistroAnimo?> registroDe(String fecha) async {
    // Lo pendiente en el celular es más nuevo que lo del servidor.
    final cola = await _leerCola();
    if (cola[fecha] != null) return cola[fecha];

    final fila = await _db
        .from('registros_animo')
        .select('id, fecha, nivel, nota, actualizado_en_cliente, '
            'registro_emociones(emocion_id), registro_factores(factor_id)')
        .eq('fecha', fecha)
        .maybeSingle();
    return fila == null ? null : RegistroAnimo.desdeJson(fila);
  }

  @override
  Future<ResultadoGuardado> guardar(RegistroAnimo registro) async {
    final cola = await _leerCola();
    cola[registro.fecha] = registro;
    await _escribirCola(cola);
    return await _subir(registro)
        ? ResultadoGuardado.sincronizado
        : ResultadoGuardado.pendienteSinConexion;
  }

  @override
  Future<void> sincronizarPendientes() async {
    final cola = await _leerCola();
    for (final r in cola.values.toList()) {
      if (!await _subir(r)) return; // Sigue sin red: no insistir con el resto.
    }
  }

  /// true = ya no está en la cola (subido o rechazado por el servidor).
  Future<bool> _subir(RegistroAnimo r) async {
    try {
      await _db.rpc('guardar_registro_animo', params: {
        'p_id': r.id,
        'p_fecha': r.fecha,
        'p_nivel': r.nivel,
        'p_emociones': r.emociones.toList(),
        'p_factores': r.factores.toList(),
        // '' borra la nota en el servidor; null la conservaría.
        'p_nota': r.nota ?? '',
        'p_actualizado_en': r.actualizadoEnCliente.toUtc().toIso8601String(),
      });
    } on PostgrestException {
      // Error de validación (ej. emocion_invalida): reintentar no lo arregla.
      // Se saca de la cola y se propaga para que la pantalla lo muestre.
      await _quitar(r.fecha);
      rethrow;
    } catch (_) {
      return false; // Sin conexión o tiempo agotado: queda en la cola.
    }
    await _quitar(r.fecha);
    return true;
  }

  Future<void> _quitar(String fecha) async {
    final cola = await _leerCola()..remove(fecha);
    await _escribirCola(cola);
  }

  Future<Map<String, RegistroAnimo>> _leerCola() async {
    final texto = await _almacen.leer(_claveCola);
    if (texto == null || texto.isEmpty) return {};
    final mapa = jsonDecode(texto) as Map<String, dynamic>;
    return mapa.map((k, v) =>
        MapEntry(k, RegistroAnimo.desdeJson(v as Map<String, dynamic>)));
  }

  Future<void> _escribirCola(Map<String, RegistroAnimo> cola) => _almacen
      .escribir(_claveCola, jsonEncode(cola.map((k, v) => MapEntry(k, v.aJson()))));

  @override
  Future<AlertaBienestar?> alertaPendiente() async {
    final r = await _db.rpc('alerta_pendiente');
    if (r == null) return null;
    final j = r as Map<String, dynamic>;
    return AlertaBienestar(id: j['id'] as String, motivo: j['motivo'] as String);
  }

  @override
  Future<void> marcarAlertaVista(String id) async {
    await _db.rpc('marcar_alerta_vista', params: {'p_id': id});
  }
}

final registroAnimoRepositorioProvider = Provider<RegistroAnimoRepositorio>(
  (_) => RegistroAnimoSupabase(Supabase.instance.client, AlmacenSeguro()),
);

/// Avisa a otras pantallas (RF-09 en el Inicio) que el ánimo de hoy cambió.
final animoGuardado = ValueNotifier<int>(0);
