// Pruebas de EstadoEvaluacionInicial (redirección al avatar).
// Se corren con:   flutter test test/core/router/

import 'dart:async';

import 'package:app_bienestar/core/router/estado_evaluacion_inicial.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deja correr los microtasks y futures pendientes (consultas simuladas).
Future<void> esperar() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late String? usuario;
  late Map<String, bool> tieneEvaluacion;
  late List<String> consultas;
  late StreamController<Object?> sesion;

  setUp(() {
    usuario = null;
    tieneEvaluacion = {};
    consultas = [];
    sesion = StreamController<Object?>.broadcast();
  });
  tearDown(() => sesion.close());

  EstadoEvaluacionInicial crear({Future<bool> Function(String id)? consulta}) =>
      EstadoEvaluacionInicial(
        usuarioActual: () => usuario,
        cambiosDeSesion: sesion.stream,
        yaTieneEvaluacion: consulta ??
            (id) async {
              consultas.add(id);
              return tieneEvaluacion[id] ?? false;
            },
      );

  /// Simula un evento de Auth y deja terminar la consulta.
  Future<void> evento() async {
    sesion.add(null);
    await esperar();
  }

  test('sin sesión: desconocida y no consulta', () async {
    final e = crear();
    await esperar();
    expect(e.situacion, SituacionEvaluacion.desconocida);
    expect(e.pendiente, isFalse);
    expect(consultas, isEmpty);
  });

  test('al iniciar sesión sin evaluación → pendiente', () async {
    final e = crear();
    usuario = 'u1';
    await evento();
    expect(e.situacion, SituacionEvaluacion.pendiente);
    expect(e.pendiente, isTrue);
  });

  test('con evaluación → completa', () async {
    tieneEvaluacion['u1'] = true;
    usuario = 'u1';
    final e = crear();
    await esperar();
    expect(e.situacion, SituacionEvaluacion.completa);
  });

  test('refrescos de token (mismo usuario) no vuelven a consultar', () async {
    usuario = 'u1';
    crear();
    await evento();
    await evento();
    expect(consultas, ['u1']);
  });

  test('omitir por ahora deja de redirigir; al volver a entrar se pregunta otra vez', () async {
    usuario = 'u1';
    final e = crear();
    await esperar();
    e.omitirPorAhora();
    expect(e.situacion, SituacionEvaluacion.omitida);
    expect(e.pendiente, isFalse);

    usuario = null; // cerrar sesión
    await evento();
    usuario = 'u1'; // volver a entrar
    await evento();
    expect(e.pendiente, isTrue);
  });

  test('marcar completa no se deshace con omitir', () async {
    usuario = 'u1';
    final e = crear();
    await esperar();
    e.marcarCompleta();
    e.omitirPorAhora();
    expect(e.situacion, SituacionEvaluacion.completa);
  });

  test('si la consulta falla no se redirige (desconocida)', () async {
    usuario = 'u1';
    final e = crear(consulta: (_) async => throw Exception('sin red'));
    await esperar();
    expect(e.situacion, SituacionEvaluacion.desconocida);
  });

  test('si cambia el usuario mientras consulta, se ignora la respuesta vieja', () async {
    final respuestas = <String, Completer<bool>>{};
    usuario = 'u1';
    final e = crear(consulta: (id) => (respuestas[id] = Completer<bool>()).future);
    usuario = 'u2';
    await evento();
    respuestas['u1']!.complete(false); // u1 "pendiente" llega tarde
    await esperar();
    expect(e.situacion, SituacionEvaluacion.desconocida);
    respuestas['u2']!.complete(true);
    await esperar();
    expect(e.situacion, SituacionEvaluacion.completa);
  });

  test('avisa a los listeners (el router se reevalúa)', () async {
    final e = crear();
    var avisos = 0;
    e.addListener(() => avisos++);
    usuario = 'u1';
    await evento();
    expect(avisos, greaterThan(0));
  });
}
