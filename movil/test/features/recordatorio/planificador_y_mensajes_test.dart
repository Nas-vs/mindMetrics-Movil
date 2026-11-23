// Pruebas de RF-22 (lógica pura). Se corren con:
//   fvm flutter test test/features/recordatorio/

import 'package:app_bienestar/features/recordatorio/domain/mensajes_recordatorio.dart';
import 'package:app_bienestar/features/recordatorio/domain/planificador_recordatorio.dart';
import 'package:app_bienestar/features/recordatorio/domain/preferencias_recordatorio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlanificadorRecordatorio', () {
    test('programa 7 días empezando hoy si la hora no ha pasado', () {
      final fechas = PlanificadorRecordatorio.proximasFechas(
        ahora: DateTime(2026, 11, 9, 10, 0),
        hora: 20,
        minuto: 0,
        registroHoy: false,
      );
      expect(fechas, hasLength(7));
      expect(fechas.first, DateTime(2026, 11, 9, 20, 0));
      expect(fechas.last, DateTime(2026, 11, 15, 20, 0));
    });

    test('CA-3: si ya registró hoy, no programa el de hoy', () {
      final fechas = PlanificadorRecordatorio.proximasFechas(
        ahora: DateTime(2026, 11, 9, 10, 0),
        hora: 20,
        minuto: 0,
        registroHoy: true,
      );
      expect(fechas.first, DateTime(2026, 11, 10, 20, 0));
      expect(fechas, hasLength(6));
    });

    test('si la hora de hoy ya pasó, empieza mañana', () {
      final fechas = PlanificadorRecordatorio.proximasFechas(
        ahora: DateTime(2026, 11, 9, 21, 0),
        hora: 20,
        minuto: 0,
        registroHoy: false,
      );
      expect(fechas.first, DateTime(2026, 11, 10, 20, 0));
    });

    test('cruza bien el fin de mes', () {
      final fechas = PlanificadorRecordatorio.proximasFechas(
        ahora: DateTime(2026, 11, 29, 8, 0),
        hora: 9,
        minuto: 30,
        registroHoy: false,
      );
      expect(fechas[2], DateTime(2026, 12, 1, 9, 30));
    });

    test('el id de cada día es AAAAMMDD', () {
      expect(PlanificadorRecordatorio.idParaFecha(DateTime(2026, 11, 9, 20)),
          20261109);
    });
  });

  group('MensajesRecordatorio (CA-2)', () {
    test('dos días seguidos no repiten mensaje', () {
      for (var d = 1; d < 30; d++) {
        final hoy = MensajesRecordatorio.paraFecha(DateTime(2026, 11, d));
        final manana = MensajesRecordatorio.paraFecha(DateTime(2026, 11, d + 1));
        expect(hoy, isNot(manana));
      }
    });

    test('el mismo día siempre da el mismo mensaje, sin importar la hora', () {
      expect(MensajesRecordatorio.paraFecha(DateTime(2026, 11, 9, 8)),
          MensajesRecordatorio.paraFecha(DateTime(2026, 11, 9, 22)));
    });
  });

  test('horaTexto muestra la hora en formato de 12 horas', () {
    expect(const PreferenciasRecordatorio(hora: 20, minuto: 5).horaTexto,
        '8:05 p. m.');
    expect(const PreferenciasRecordatorio(hora: 0, minuto: 0).horaTexto,
        '12:00 a. m.');
  });
}
