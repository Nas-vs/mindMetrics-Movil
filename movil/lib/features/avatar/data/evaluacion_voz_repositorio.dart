import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Errores de dominio al guardar la evaluación. La UI solo conoce estos.
enum ErrorEvaluacion { yaExiste, datoInvalido, sinPermiso, sinConexion, servidor }

class EvaluacionExcepcion implements Exception {
  const EvaluacionExcepcion(this.tipo);
  final ErrorEvaluacion tipo;

  @override
  String toString() => 'EvaluacionExcepcion($tipo)';
}

/// Traduce el SQLSTATE de PostgREST. Contrato en la migración
/// `20261108120000_motor_evaluacion_inicial.sql`.
ErrorEvaluacion errorDePostgrest(String? codigo) => switch (codigo) {
      '23505' => ErrorEvaluacion.yaExiste, // una evaluación inicial por usuario
      '23514' || '23502' => ErrorEvaluacion.datoInvalido, // CHECK / NOT NULL
      '42501' => ErrorEvaluacion.sinPermiso, // RLS o columna no permitida
      _ => ErrorEvaluacion.servidor,
    };

/// Guarda la evaluación inicial que armó la conversación.
/// Al insertarla, Supabase avisa al motor (pg_notify) y el nivel aparece en
/// `nivel_riesgo_actual` en unos segundos.
class EvaluacionVozRepositorio {
  EvaluacionVozRepositorio([SupabaseClient? cliente]) : _cliente = cliente;

  final SupabaseClient? _cliente;
  SupabaseClient get _db => _cliente ?? Supabase.instance.client;

  Future<void> guardar(Map<String, Object> fila) async {
    try {
      // usuario_id y edad los pone el servidor (default auth.uid() y trigger)
      await _db.from('evaluaciones_iniciales').insert(fila);
    } on PostgrestException catch (e) {
      throw EvaluacionExcepcion(errorDePostgrest(e.code));
    } on SocketException {
      throw const EvaluacionExcepcion(ErrorEvaluacion.sinConexion);
    }
  }
}
