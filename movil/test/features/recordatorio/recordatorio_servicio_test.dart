// Pruebas de RF-22: el servicio con notificaciones y Supabase falsos.

import 'package:app_bienestar/features/recordatorio/data/almacen_clave_valor.dart';
import 'package:app_bienestar/features/recordatorio/data/notificaciones_servicio.dart';
import 'package:app_bienestar/features/recordatorio/data/preferencias_recordatorio_repositorio.dart';
import 'package:app_bienestar/features/recordatorio/data/recordatorio_servicio.dart';
import 'package:app_bienestar/features/recordatorio/data/registro_hoy_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

class NotificacionesFalsas implements NotificacionesServicio {
  bool permiso = true;
  int vecesPermisoPedido = 0;
  final programadas = <int, DateTime>{};

  @override
  Future<bool> pedirPermiso() async {
    vecesPermisoPedido++;
    return permiso;
  }

  @override
  Future<void> programar({
    required int id,
    required DateTime cuando,
    required String titulo,
    required String texto,
  }) async =>
      programadas[id] = cuando;

  @override
  Future<void> cancelar(int id) async => programadas.remove(id);

  @override
  Future<void> cancelarTodas() async => programadas.clear();

  @override
  Future<void> mostrarAhora({required String titulo, required String texto}) async {}
}

class RegistroHoyFalso implements RegistroHoyRepositorio {
  bool registro = false;
  @override
  Future<bool> yaRegistroHoy() async => registro;
}

void main() {
  late NotificacionesFalsas notificaciones;
  late RegistroHoyFalso registroHoy;
  late PreferenciasRecordatorioRepositorio preferencias;
  late RecordatorioServicio servicio;

  // "Ahora" fijo: lunes 9 de noviembre, 10:00 a. m.
  final ahora = DateTime(2026, 11, 9, 10, 0);
  const idHoy = 20261109;

  setUp(() {
    notificaciones = NotificacionesFalsas();
    registroHoy = RegistroHoyFalso();
    preferencias = PreferenciasRecordatorioRepositorio(AlmacenEnMemoria());
    servicio = RecordatorioServicio(
      notificaciones: notificaciones,
      preferencias: preferencias,
      registroHoy: registroHoy,
      reloj: () => ahora,
    );
  });

  test('por defecto el recordatorio está apagado y no programa nada', () async {
    await servicio.reprogramar();
    expect(notificaciones.programadas, isEmpty);
    expect(notificaciones.vecesPermisoPedido, 0);
  });

  test('CA-1: tras el primer registro explica y, si acepta, pide permiso y programa',
      () async {
    var preguntas = 0;
    final activo = await servicio.despuesDeRegistrarAnimo(
      preguntarAlUsuario: () async {
        preguntas++;
        return true;
      },
    );
    expect(preguntas, 1);
    expect(notificaciones.vecesPermisoPedido, 1);
    expect(activo, isTrue);
    expect(notificaciones.programadas, isNotEmpty);
  });

  test('CA-1: la explicación se muestra una sola vez', () async {
    var preguntas = 0;
    Future<bool> preguntar() async {
      preguntas++;
      return false;
    }

    await servicio.despuesDeRegistrarAnimo(preguntarAlUsuario: preguntar);
    await servicio.despuesDeRegistrarAnimo(preguntarAlUsuario: preguntar);
    expect(preguntas, 1);
    expect(notificaciones.vecesPermisoPedido, 0, reason: 'dijo "Ahora no"');
  });

  test('si niega el permiso del sistema, el recordatorio queda apagado', () async {
    notificaciones.permiso = false;
    final activo = await servicio.activar();
    expect(activo, isFalse);
    expect((await preferencias.leer()).activo, isFalse);
    expect(notificaciones.programadas, isEmpty);
  });

  test('CA-3: al registrar el ánimo se cancela la notificación de hoy', () async {
    await servicio.activar();
    expect(notificaciones.programadas.containsKey(idHoy), isTrue);

    await servicio.despuesDeRegistrarAnimo(preguntarAlUsuario: () async => true);

    expect(notificaciones.programadas.containsKey(idHoy), isFalse);
    expect(notificaciones.programadas.containsKey(20261110), isTrue,
        reason: 'mañana sí debe sonar');
  });

  test('CA-3: al reprogramar no se agenda hoy si ya registró', () async {
    registroHoy.registro = true;
    await servicio.activar();
    expect(notificaciones.programadas.containsKey(idHoy), isFalse);
  });

  test('cambiar la hora reprograma todo a la hora nueva', () async {
    await servicio.activar();
    await servicio.cambiarHora(18, 30);
    expect(notificaciones.programadas[idHoy], DateTime(2026, 11, 9, 18, 30));
  });

  test('desactivar y cerrar sesión cancelan todo', () async {
    await servicio.activar();
    await servicio.desactivar();
    expect(notificaciones.programadas, isEmpty);

    await servicio.activar();
    await servicio.cancelarTodo();
    expect(notificaciones.programadas, isEmpty);
  });
}
