import 'package:app_bienestar/features/avatar/data/voz/escucha_una_vez.dart';
import 'package:app_bienestar/features/avatar/data/voz/idiomas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EscuchaUnaVez', () {
    test('el resultado final termina la escucha con el texto', () async {
      final e = EscuchaUnaVez()
        ..alResultado('duermo', esFinal: false)
        ..alResultado('duermo seis horas', esFinal: true);
      expect(await e.futuro, 'duermo seis horas');
    });

    test('"done" sin resultado final devuelve el último parcial', () async {
      final e = EscuchaUnaVez()
        ..alResultado('cuarenta', esFinal: false)
        ..alEstado('notListening')
        ..alEstado('done');
      expect(await e.futuro, 'cuarenta');
    });

    test('silencio: "done" sin nada dicho devuelve null', () async {
      final e = EscuchaUnaVez()..alEstado('done');
      expect(await e.futuro, isNull);
      expect(e.ultimoError, isNull);
    });

    test('error de silencio no se reporta como error', () async {
      final e = EscuchaUnaVez()..alError('error_speech_timeout');
      expect(await e.futuro, isNull);
      expect(e.ultimoError, isNull);
    });

    test('otro error termina con null y queda registrado', () async {
      final e = EscuchaUnaVez()..alError('error_network');
      expect(await e.futuro, isNull);
      expect(e.ultimoError, 'error_network');
    });

    test('solo cuenta el primer final; lo que llega después se ignora', () async {
      final e = EscuchaUnaVez()
        ..alResultado('sí', esFinal: true)
        ..alResultado('no', esFinal: true)
        ..cancelar();
      expect(await e.futuro, 'sí');
    });

    test('un resultado final vacío conserva el parcial anterior', () async {
      final e = EscuchaUnaVez()
        ..alResultado('siete', esFinal: false)
        ..alResultado('', esFinal: true);
      expect(await e.futuro, 'siete');
    });
  });

  group('elegirIdioma', () {
    test('prefiere español de Colombia, con "_" o "-"', () {
      expect(elegirIdioma(['en_US', 'es_ES', 'es_CO']), 'es_CO');
      expect(elegirIdioma(['es-ES', 'es-CO']), 'es-CO');
    });

    test('sin Colombia usa la variante latinoamericana más cercana', () {
      expect(elegirIdioma(['es-ES', 'es-US', 'en-US']), 'es-US');
      expect(elegirIdioma(['es-ES', 'es-MX']), 'es-MX');
    });

    test('usa el idioma del sistema si es español y no está en la preferencia', () {
      expect(elegirIdioma(['en_US', 'es_AR'], delSistema: 'es_AR'), 'es_AR');
    });

    test('cualquier español antes que nada', () {
      expect(elegirIdioma(['fr-FR', 'es-PE']), 'es-PE');
    });

    test('sin español devuelve null', () {
      expect(elegirIdioma(['en-US', 'pt-BR'], delSistema: 'en_US'), isNull);
    });
  });
}
