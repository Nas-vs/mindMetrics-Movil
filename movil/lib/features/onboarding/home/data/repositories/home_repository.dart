import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../animo/domain/registro_animo.dart';
import '../models/home_summary_model.dart';

/// Fuente de datos del Inicio.
abstract class HomeRepository {
  Future<HomeSummaryModel> getHomeSummary();
}

/// Inicio con datos reales de Supabase.
///
/// - RF-07 CA-2: el nickname sale de la sesión en memoria
///   (`appMetadata['nickname']`, trigger de RF-07), sin ir a la red.
/// - Estado de hoy, racha y semana: `registros_animo` (RF-08), RLS por usuario.
/// - Resultado de la evaluación: `evaluaciones_iniciales` + vista
///   `nivel_riesgo_actual` (migración del motor, security_invoker).
///
/// Cada consulta falla por separado: sin red, el panel muestra lo que pudo
/// leer en vez de quedarse en error.
class HomeRepositorySupabase implements HomeRepository {
  HomeRepositorySupabase({
    this._cliente,
    String? Function()? obtenerNickname,
    DateTime Function()? ahora,
  })  : _obtenerNickname = obtenerNickname ?? _leerNicknameDeSesion,
        _ahora = ahora ?? DateTime.now;

  final SupabaseClient? _cliente;
  final String? Function() _obtenerNickname;
  final DateTime Function() _ahora;

  /// Ventana para la racha y la última semana registrada.
  static const _diasHistorial = 120;

  static String? _leerNicknameDeSesion() {
    try {
      final nickname = Supabase.instance.client.auth.currentUser?.appMetadata['nickname'];
      if (nickname is String && nickname.trim().isNotEmpty) return nickname.trim();
    } catch (_) {
      // Supabase sin inicializar (pruebas de widgets).
    }
    return null;
  }

  SupabaseClient? get _db {
    if (_cliente != null) return _cliente;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<HomeSummaryModel> getHomeSummary() async {
    final hoy = _ahora();
    final username = _obtenerNickname() ?? 'Usuario';
    final db = _db;
    if (db == null) return HomeSummaryModel(username: username);

    final (niveles, evaluacion) = await (_niveles(db, hoy), _evaluacion(db)).wait;

    return HomeSummaryModel(
      username: username,
      animoHoy: niveles[fechaLocal(hoy)],
      evaluacion: evaluacion,
      racha: HomeSummaryModel.calcularRacha(niveles, hoy),
      semana: HomeSummaryModel.ultimaSemanaRegistrada(niveles, hoy),
    );
  }

  /// fecha 'AAAA-MM-DD' → nivel 1–5. Una fila por día (unique en RF-08).
  Future<Map<String, int>> _niveles(SupabaseClient db, DateTime hoy) async {
    try {
      final desde = DateTime(hoy.year, hoy.month, hoy.day - _diasHistorial);
      final filas = await db
          .from('registros_animo')
          .select('fecha, nivel')
          .gte('fecha', fechaLocal(desde))
          .lte('fecha', fechaLocal(hoy))
          .order('fecha', ascending: false);
      return {
        for (final f in filas) f['fecha'] as String: (f['nivel'] as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<ResultadoEvaluacion> _evaluacion(SupabaseClient db) async {
    try {
      final evaluacion = await db
          .from('evaluaciones_iniciales')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (evaluacion == null) return const ResultadoEvaluacion.pendiente();

      final nivel = await db
          .from('nivel_riesgo_actual')
          .select('nivel, origen, calculado_en')
          .limit(1)
          .maybeSingle();
      return nivel == null
          ? const ResultadoEvaluacion.calculando()
          : ResultadoEvaluacion.desdeJson(nivel);
    } catch (_) {
      return const ResultadoEvaluacion.desconocido();
    }
  }
}
