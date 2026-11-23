import 'package:app_bienestar/features/avatar/domain/dialogo/sesion_dialogo.dart';
import 'package:app_bienestar/features/avatar/domain/estado_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyo.dart';

const _tipos = {
  'pregunta': TipoTurno.pregunta,
  'confirmacion': TipoTurno.confirmacion,
  'aclaracion': TipoTurno.aclaracion,
  'crisis': TipoTurno.crisis,
  'fin': TipoTurno.fin,
  'formulario': TipoTurno.formulario,
};

void _verificar(Turno t, Map<String, dynamic> esperado, String donde) {
  expect(t.tipo, _tipos[esperado['tipo']], reason: '$donde · tipo (${t.texto})');
  if (esperado.containsKey('campo')) expect(t.campo, esperado['campo'], reason: '$donde · campo');
  if (esperado.containsKey('emocion')) {
    expect(t.emocion, EmocionAvatar.values.byName(esperado['emocion'] as String), reason: '$donde · emoción');
  }
  if (esperado.containsKey('opciones')) {
    expect(t.opciones, hasLength(esperado['opciones']), reason: '$donde · opciones');
  }
  if (esperado.containsKey('contiene')) {
    expect(t.texto, contains(esperado['contiene']), reason: '$donde · texto');
  }
}

void main() {
  final guion = cargarGuion();
  final datos = cargarCasos('casos_sesion.json');
  final previas = (datos['respuestas_previas'] as Map<String, dynamic>);

  group('escenarios compartidos (casos_sesion.json)', () {
    for (final e in (datos['escenarios'] as List).cast<Map<String, dynamic>>()) {
      test(e['nombre'] as String, () {
        final s = SesionDialogo(guion);
        var t = s.iniciar();
        if (e['inicio'] != null) _verificar(t, e['inicio'] as Map<String, dynamic>, 'inicio');

        final hasta = e['hasta'] as String?;
        if (hasta != null) {
          while (t.campo != hasta) {
            t = s.responder(previas[t.campo] as String);
            expect(t.tipo, TipoTurno.pregunta, reason: 'llegando a $hasta');
          }
        }

        final pasos = (e['pasos'] as List).cast<Map<String, dynamic>>();
        for (var i = 0; i < pasos.length; i++) {
          final paso = pasos[i];
          t = paso.containsKey('elige') ? s.elegir(paso['elige'] as Object) : s.responder(paso['dice'] as String);
          _verificar(t, paso, 'paso $i');
        }

        final respuestas = (e['respuestas'] as Map<String, dynamic>?) ?? const {};
        respuestas.forEach((campo, valor) {
          expect(s.respuestas[campo], valor, reason: campo);
          expect(s.respuestas[campo] is bool, valor is bool, reason: '$campo · tipo');
        });
        if (e.containsKey('hubo_crisis')) expect(s.huboCrisis, e['hubo_crisis']);
      });
    }
  });

  group('fila para Supabase', () {
    SesionDialogo completa() {
      final s = SesionDialogo(guion);
      var t = s.iniciar();
      while (t.tipo != TipoTurno.fin) {
        t = s.responder(previas[t.campo] as String);
      }
      return s;
    }

    test('trae canal voz y las 19 columnas, con los tipos de la tabla', () {
      final fila = completa().filaSupabase();
      expect(fila['canal'], 'voz');
      expect(fila.length, 20);
      expect(fila['hr_sueno'], isA<double>());
      expect(fila['estres_laboral'], isA<int>());
      expect(fila['uso_sustancias'], isA<bool>());
      expect(fila['genero'], 'femenino');
      expect(fila.keys.where((k) => k.startsWith('_')), isEmpty, reason: 'las transiciones no se guardan');
    });

    test('no se puede pedir la fila antes de terminar', () {
      final s = SesionDialogo(guion)..iniciar();
      expect(s.filaSupabase, throwsStateError);
    });

    test('la bienvenida usa el nombre de la mascota', () {
      expect(SesionDialogo(guion, mascota: 'Plip').iniciar().texto, contains('Soy Plip'));
    });

    test('la bienvenida saluda por el apodo del registro', () {
      final t = SesionDialogo(guion, apodo: 'juli_23').iniciar().texto;
      expect(t, startsWith('¡Hola, juli_23! Soy Nimbus.'));
    });

    test('sin apodo se saluda sin nombre y no queda el marcador', () {
      final t = SesionDialogo(guion).iniciar().texto;
      expect(t, startsWith('¡Hola! Soy Nimbus.'));
      expect(t, isNot(contains('{')));
    });

    test('la despedida también usa el apodo', () {
      final s = SesionDialogo(guion, apodo: 'juli_23');
      var t = s.iniciar();
      while (t.tipo != TipoTurno.fin) {
        t = s.responder(previas[t.campo] as String);
        if (t.tipo == TipoTurno.confirmacion) t = s.responder('sí');
      }
      expect(t.texto, contains('¡Listo, juli_23, terminamos!'));
    });
  });

  group('personalizar', () {
    test('reemplaza mascota y apodo', () {
      expect(personalizar('¡Hola, {apodo}! Soy {mascota}.', mascota: 'Plip', apodo: 'Ana'),
          '¡Hola, Ana! Soy Plip.');
    });

    test('sin apodo (null, vacío o espacios) quita el marcador con su coma', () {
      for (final apodo in [null, '', '   ']) {
        expect(personalizar('¡Hola, {apodo}!', mascota: 'N', apodo: apodo), '¡Hola!');
        expect(personalizar('¡Listo, {apodo}, terminamos!', mascota: 'N', apodo: apodo),
            '¡Listo, terminamos!');
        expect(personalizar('{apodo}, ¿seguimos?', mascota: 'N', apodo: apodo), '¿seguimos?');
      }
    });

    test('elegir rechaza un valor que no es opción de la pregunta', () {
      final s = SesionDialogo(guion)..iniciar();
      expect(() => s.elegir('marciano'), throwsArgumentError);
    });

    test('la transición a las preguntas personales se dice antes de apoyo_percibido', () {
      final s = SesionDialogo(guion);
      var t = s.iniciar();
      while (t.campo != 'apoyo_percibido') {
        t = s.responder(previas[t.campo] as String);
      }
      expect(t.texto, contains('preguntas más personales'));
      expect(t.emocion, EmocionAvatar.empatico);
    });
  });
}
