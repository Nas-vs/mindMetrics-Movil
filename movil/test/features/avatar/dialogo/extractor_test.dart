import 'package:app_bienestar/features/avatar/domain/dialogo/extractor.dart';
import 'package:app_bienestar/features/avatar/domain/dialogo/texto_es.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoyo.dart';

const _motivos = {
  'ok': MotivoExtraccion.ok,
  'sin_valor': MotivoExtraccion.sinValor,
  'ambiguo': MotivoExtraccion.ambiguo,
  'fuera_de_rango': MotivoExtraccion.fueraDeRango,
};

void main() {
  final guion = cargarGuion();

  group('normalizar', () {
    test('quita tildes, signos y deja la coma decimal como punto', () {
      expect(normalizar('¿Sí? Duermo 6,5 HORAS… ¡Ñandú!'), 'si duermo 6.5 horas nandu');
    });
    test('contiene compara palabras completas', () {
      expect(contiene('siempre', 'si'), isFalse);
      expect(contiene('pues si claro', 'si'), isTrue);
    });
  });

  group('números en palabras', () {
    final casos = {
      'cuarenta y ocho': 48.0,
      'ciento veinte': 120.0,
      'veintitres': 23.0,
      'siete y media': 7.5,
      'una hora y media': 1.5,
      'media hora': 0.5,
      'hora y media': 1.5,
      'dos y cuarto': 2.25,
      '6.5': 6.5,
    };
    casos.forEach((texto, valor) {
      test('"$texto" → $valor', () {
        final ns = numeros(normalizar(texto));
        expect(ns, hasLength(1));
        expect(ns.single.valor, valor);
      });
    });
    test('"un ocho": el artículo no cuenta como número', () {
      expect(numeros('un ocho').map((n) => n.valor), [8.0]);
    });
  });

  group('casos compartidos (casos_extractor.json)', () {
    final casos = (cargarCasos('casos_extractor.json')['casos'] as List).cast<Map<String, dynamic>>();
    for (final c in casos) {
      test('${c['campo']}: "${c['texto']}"', () {
        final ex = extraer(c['texto'] as String, pregunta(guion, c['campo'] as String));
        expect(ex.motivo, _motivos[c['motivo']], reason: 'motivo');
        if (c['motivo'] == 'ok') {
          expect(ex.valor, c['valor'], reason: 'valor');
          expect(ex.valor is bool, c['valor'] is bool, reason: 'tipo');
          expect(ex.confianza < guion.umbralConfirmacion, c['confirma'], reason: 'reconfirmar');
        }
      });
    }
  });
}
