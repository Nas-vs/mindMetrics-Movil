import 'dart:io';
import 'dart:math' as math;

import 'package:app_bienestar/features/avatar/domain/capas_avatar.dart';
import 'package:app_bienestar/features/avatar/domain/estado_avatar.dart';
import 'package:app_bienestar/features/avatar/domain/generador_silabas.dart';
import 'package:app_bienestar/features/avatar/domain/personaje_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

const _hablando = EstadoAvatar(actividad: ActividadAvatar.hablando);

void main() {
  group('ojosPara', () {
    test('neutral en reposo -> abiertos', () {
      expect(CapasAvatar.ojosPara(EstadoAvatar.inicial, parpadeando: false),
          CapaOjos.abiertos);
    });
    test('parpadeo -> cerrados', () {
      expect(CapasAvatar.ojosPara(EstadoAvatar.inicial, parpadeando: true),
          CapaOjos.cerrados);
    });
    test('alegre no parpadea (ya están entrecerrados)', () {
      const alegre = EstadoAvatar(emocion: EmocionAvatar.alegre);
      expect(CapasAvatar.ojosPara(alegre, parpadeando: true), CapaOjos.felices);
    });
    test('empático -> ojos con cejas', () {
      const e = EstadoAvatar(emocion: EmocionAvatar.empatico);
      expect(CapasAvatar.ojosPara(e, parpadeando: false), CapaOjos.empaticos);
    });
    test('pensando gana sobre la emoción', () {
      const e = EstadoAvatar(
          actividad: ActividadAvatar.pensando, emocion: EmocionAvatar.alegre);
      expect(CapasAvatar.ojosPara(e, parpadeando: false), CapaOjos.pensando);
    });
  });

  group('bocaPara en silencio', () {
    test('neutral -> sonrisa', () {
      expect(CapasAvatar.bocaPara(EstadoAvatar.inicial), CapaBoca.sonrisa);
    });
    test('alegre -> alegre', () {
      expect(CapasAvatar.bocaPara(const EstadoAvatar(emocion: EmocionAvatar.alegre)),
          CapaBoca.alegre);
    });
    test('empático -> suave', () {
      expect(
          CapasAvatar.bocaPara(const EstadoAvatar(emocion: EmocionAvatar.empatico)),
          CapaBoca.suave);
    });
    test('pensando -> pensando', () {
      expect(
          CapasAvatar.bocaPara(
              const EstadoAvatar(actividad: ActividadAvatar.pensando)),
          CapaBoca.pensando);
    });
    test('el nivel de voz se ignora si no habla', () {
      expect(CapasAvatar.bocaPara(EstadoAvatar.inicial, nivelVoz: 1),
          CapaBoca.sonrisa);
    });
  });

  group('bocaPara hablando (visemas)', () {
    final casos = {
      0.0: CapaBoca.cerrada,
      0.07: CapaBoca.cerrada,
      0.08: CapaBoca.pequena,
      0.34: CapaBoca.pequena,
      0.35: CapaBoca.media,
      0.64: CapaBoca.media,
      0.65: CapaBoca.abierta,
      1.0: CapaBoca.abierta,
    };
    casos.forEach((nivel, esperada) {
      test('nivel $nivel -> ${esperada.name}', () {
        expect(CapasAvatar.bocaPara(_hablando, nivelVoz: nivel), esperada);
      });
    });
    test('vocal redonda cambia media por o', () {
      expect(
          CapasAvatar.bocaPara(_hablando, nivelVoz: 0.5, vocalRedonda: true),
          CapaBoca.o);
    });
    test('siempre devuelve un visema', () {
      for (var n = 0.0; n <= 1.0; n += 0.05) {
        expect(CapasAvatar.bocaPara(_hablando, nivelVoz: n).esVisema, isTrue);
      }
    });
  });

  group('GeneradorSilabas', () {
    test('mantiene el nivel entre 0 y 1 y alterna sílabas y pausas', () {
      final g = GeneradorSilabas(aleatorio: math.Random(7));
      var maximo = 0.0, ceros = 0;
      for (var i = 0; i < 600; i++) {
        final n = g.avanzar(const Duration(milliseconds: 16));
        expect(n, inInclusiveRange(0.0, 1.0));
        if (n > maximo) maximo = n;
        if (n < CapasAvatar.umbralPequena) ceros++;
      }
      expect(maximo, greaterThan(CapasAvatar.umbralAbierta));
      expect(ceros, greaterThan(0));
    });
    test('reiniciar deja la boca cerrada', () {
      final g = GeneradorSilabas(aleatorio: math.Random(1))
        ..avanzar(const Duration(milliseconds: 60));
      g.reiniciar();
      expect(g.nivel, 0);
    });
  });

  group('contrato de assets', () {
    for (final p in PersonajesAvatar.todos) {
      test('${p.id} trae todas las capas con viewBox 240', () {
        for (final capa in CapasAvatar.todas) {
          final archivo = File(p.ruta(capa));
          expect(archivo.existsSync(), isTrue, reason: 'falta ${archivo.path}');
          expect(archivo.readAsStringSync(), contains('viewBox="0 0 240 240"'),
              reason: archivo.path);
        }
      });
    }
    test('porId cae en Nimbus si el id no existe', () {
      expect(PersonajesAvatar.porId('gato'), PersonajesAvatar.nimbus);
      expect(PersonajesAvatar.porId('plip'), PersonajesAvatar.plip);
    });
  });
}
