import 'package:app_bienestar/features/avatar/domain/dialogo/sesion_dialogo.dart';
import 'package:app_bienestar/features/avatar/domain/estado_avatar.dart';
import 'package:app_bienestar/features/avatar/domain/servicio_voz.dart';
import 'package:app_bienestar/features/avatar/presentation/avatar_controlador.dart';
import 'package:app_bienestar/features/avatar/presentation/conversacion_controlador.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialogo/apoyo.dart';

/// Voz falsa: habla al instante y "oye" lo que haya en la cola
/// (null = silencio).
class VozFalsa implements ServicioVoz {
  VozFalsa(this.oir, {this.escucha = true});

  final List<String?> oir;
  final bool escucha;
  final dichos = <String>[];
  final estadosAvatarAlEscuchar = <ActividadAvatar>[];
  AvatarControlador? avatar;

  @override
  bool get admiteEscucha => escucha;

  @override
  Future<void> hablar(String texto) async => dichos.add(texto);

  @override
  Future<String?> escuchar() async {
    if (avatar != null) estadosAvatarAlEscuchar.add(avatar!.estado.actividad);
    return oir.isEmpty ? null : oir.removeAt(0);
  }

  @override
  Future<void> detener() async {}
}

const _respuestas = [
  'mujer', 'soltera', 'estudiante', 'siete', 'cuarenta', 'tres', 'dos', 'cinco', 'cinco', 'cinco',
  'cinco', 'cinco', 'a veces', 'alto', 'no', 'no', 'no', 'nunca', 'no',
];

void main() {
  final guion = cargarGuion();
  late AvatarControlador avatar;
  late List<Map<String, Object>> guardadas;

  setUp(() {
    avatar = AvatarControlador();
    guardadas = [];
  });

  ConversacionControlador crear(ServicioVoz voz, {Future<void> Function(Map<String, Object>)? guardar}) =>
      ConversacionControlador(
        guion: guion,
        voz: voz,
        avatar: avatar,
        guardar: guardar ?? (fila) async => guardadas.add(fila),
      );

  test('por voz: completa la encuesta y la guarda una sola vez', () async {
    final voz = VozFalsa([..._respuestas])..avatar = avatar;
    final c = crear(voz);
    await c.iniciar();

    expect(c.estado, EstadoConversacion.terminada);
    expect(guardadas, hasLength(1));
    expect(guardadas.single['canal'], 'voz');
    expect(guardadas.single['hr_trabajo'], 40);
    expect(voz.estadosAvatarAlEscuchar.toSet(), {ActividadAvatar.escuchando},
        reason: 'el avatar muestra que escucha mientras el micrófono está abierto');
    expect(c.historial.where((m) => !m.deAvatar), hasLength(_respuestas.length));
    expect(avatar.estado.emocion, EmocionAvatar.alegre);
  });

  test('tres silencios seguidos pausan; "seguir" retoma', () async {
    final voz = VozFalsa([null, null, null]);
    final c = crear(voz);
    await c.iniciar();
    expect(c.estado, EstadoConversacion.pausada);
    expect(c.turno!.campo, 'genero');

    voz.oir.add('mujer');
    await c.seguir(); // escucha "mujer", pregunta lo siguiente y vuelve a pausar por silencio
    expect(c.sesion.respuestas['genero'], 'femenino');
    expect(c.estado, EstadoConversacion.pausada);
  });

  test('crisis: se detiene, muestra las líneas y sigue con "sigamos"', () async {
    final voz = VozFalsa(['mujer', 'no quiero vivir', null]);
    final c = crear(voz);
    await c.iniciar();
    expect(c.estado, EstadoConversacion.crisis);
    expect(c.huboCrisis, isTrue);
    expect(c.lineasCrisis.map((l) => l.numero), contains('106'));
    expect(avatar.estado.emocion, EmocionAvatar.empatico);

    // Dice "sigamos" y luego responde la pregunta que quedó abierta
    voz.oir.add('soltera');
    await c.responderTexto('sigamos');
    expect(voz.dichos, contains(startsWith('Gracias por decírmelo. Seguimos donde íbamos.')));
    expect(c.sesion.respuestas['estado_relacion'], 'soltero');
  });

  test('sin micrófono: espera texto y acepta toques en las opciones', () async {
    final c = crear(VozFalsa([], escucha: false));
    await c.iniciar();
    expect(c.estado, EstadoConversacion.esperandoTexto);

    await c.responderTexto('es complicado');
    await c.responderTexto('no sabría');
    expect(c.turno!.opciones, isNotEmpty, reason: 'tras dos intentos muestra opciones');
    await c.elegir(c.turno!.opciones.firstWhere((o) => o.valor == 'otro'));
    expect(c.sesion.respuestas['genero'], 'otro');
  });

  test('confirmación con los botones Sí/No', () async {
    final c = crear(VozFalsa([], escucha: false));
    await c.iniciar();
    for (final r in ['mujer', 'soltera', 'estudiante', 'siete']) {
      await c.responderTexto(r);
    }
    await c.responderTexto('ocho al día');
    expect(c.turno!.tipo, TipoTurno.confirmacion);
    await c.elegir(c.turno!.opciones.firstWhere((o) => o.valor == true));
    expect(c.sesion.respuestas['hr_trabajo'], 40);
  });

  test('pedir el formulario corta la conversación', () async {
    final c = crear(VozFalsa(['prefiero el formulario']));
    await c.iniciar();
    expect(c.estado, EstadoConversacion.formulario);
    expect(guardadas, isEmpty);
  });

  test('si falla el guardado queda en error y se puede reintentar', () async {
    var intentos = 0;
    final c = crear(VozFalsa([..._respuestas]), guardar: (fila) async {
      if (++intentos == 1) throw Exception('sin red');
      guardadas.add(fila);
    });
    await c.iniciar();
    expect(c.estado, EstadoConversacion.error);

    await c.reintentarGuardado();
    expect(c.estado, EstadoConversacion.terminada);
    expect(guardadas, hasLength(1));
  });
}
