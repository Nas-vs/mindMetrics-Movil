import 'package:app_bienestar/features/avatar/domain/dialogo/guion.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyo.dart';

/// Vocabulario de los CHECK de `evaluaciones_iniciales`
/// (migración 20261108120000_motor_evaluacion_inicial.sql) y de mapper.py.
const _vocabulario = {
  'genero': ['femenino', 'masculino', 'no_binario', 'otro'],
  'estado_relacion': ['soltero', 'noviazgo', 'union libre', 'casado', 'poliamor', 'divorciado', 'viudo'],
  'situacion_trabajo': [
    'estudiante', 'empleado tiempo completo', 'empleado medio tiempo', 'independiente',
    'contrato temporal', 'desempleado', 'pensionado',
  ],
  'dificultad_concentra': ['ninguno', 'ocasional', 'frecuente'],
  'tratamiento_previo': ['ninguno', 'adherente', 'abandono'],
  'apoyo_percibido': ['excelente', 'alto', 'moderado', 'intermitente', 'poco', 'nulo'],
};

const _columnas = [
  'genero', 'estado_relacion', 'situacion_trabajo', 'hr_sueno', 'hr_trabajo', 'hr_pantalla',
  'hr_act_fis', 'estres_laboral', 'estres_academico', 'estres_financ', 'satisfaccion_laboral',
  'cambio_emocional', 'uso_sustancias', 'diagnostico_previo', 'historial_panico',
  'historial_familiar', 'dificultad_concentra', 'tratamiento_previo', 'apoyo_percibido',
];

void main() {
  final guion = cargarGuion();

  test('pregunta exactamente las 19 columnas de la evaluación inicial', () {
    final campos = guion.preguntasConRespuesta.map((p) => p.campo).toList();
    expect(campos.toSet(), _columnas.toSet());
    expect(campos, hasLength(_columnas.length), reason: 'sin preguntas repetidas');
  });

  _vocabulario.forEach((campo, valores) {
    test('$campo usa el vocabulario exacto del motor', () {
      expect(pregunta(guion, campo).opciones.map((o) => o.valor).toSet(), valores.toSet());
    });
  });

  test('ningún sinónimo está en dos opciones de la misma pregunta', () {
    for (final p in guion.preguntas.where((p) => p.tipo == TipoPregunta.opcion)) {
      final vistos = <String, String>{};
      for (final o in p.opciones) {
        for (final s in o.sinonimos) {
          expect(vistos[s] == null || vistos[s] == o.valor, isTrue,
              reason: '${p.campo}: "$s" está en ${vistos[s]} y ${o.valor}');
          vistos[s] = o.valor;
        }
      }
    }
  });

  test('números y escalas tienen rango; los semanales dicen cuántos días', () {
    for (final p in guion.preguntasConRespuesta) {
      if (p.tipo == TipoPregunta.numero || p.tipo == TipoPregunta.escala) {
        expect(p.min, isNotNull, reason: p.campo);
        expect(p.max, isNotNull, reason: p.campo);
      }
      if (p.periodo == 'semana') expect(p.diasPorSemana, inInclusiveRange(1, 7), reason: p.campo);
    }
  });

  test('crisis: tiene frases, forma de continuar y al menos una línea de ayuda', () {
    expect(guion.crisis.frases, isNotEmpty);
    expect(guion.crisis.continuar, isNotEmpty);
    expect(guion.crisis.lineas.map((l) => l.numero), containsAll(['106', '192', '123']));
  });

  test('todos los mensajes que usa la sesión existen', () {
    for (final clave in [
      'no_entendi', 'fuera_de_rango', 'confirmar', 'confirmado', 'corregir',
      'usar_opciones', 'formulario', 'continuar_tras_crisis',
    ]) {
      expect(guion.mensajes[clave], isNotNull, reason: clave);
    }
  });
}
