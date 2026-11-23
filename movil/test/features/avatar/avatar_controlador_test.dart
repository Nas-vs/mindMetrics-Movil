import 'package:app_bienestar/features/avatar/domain/estado_avatar.dart';
import 'package:app_bienestar/features/avatar/presentation/avatar_controlador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AvatarControlador c;
  late int avisos;

  setUp(() {
    c = AvatarControlador();
    avisos = 0;
    c.addListener(() => avisos++);
  });

  tearDown(() => c.dispose());

  test('arranca en reposo y neutral', () {
    expect(c.estado, EstadoAvatar.inicial);
  });

  test('ciclo de un turno', () {
    c.hablar(emocion: EmocionAvatar.empatico);
    expect(c.estado,
        const EstadoAvatar(actividad: ActividadAvatar.hablando, emocion: EmocionAvatar.empatico));
    c.escuchar();
    expect(c.estado.actividad, ActividadAvatar.escuchando);
    expect(c.estado.emocion, EmocionAvatar.empatico, reason: 'conserva la emoción');
    c.pensar();
    expect(c.estado.actividad, ActividadAvatar.pensando);
    c.detener();
    expect(c.estado.actividad, ActividadAvatar.inactivo);
    expect(avisos, 4);
  });

  test('no notifica si el estado no cambia', () {
    c.escuchar();
    c.escuchar();
    expect(avisos, 1);
  });

  test('nivel de voz externo solo aplica mientras habla', () {
    c.actualizarNivelVoz(0.8);
    expect(c.usaNivelExterno, isFalse);
    expect(c.nivelVoz, 0);

    c.hablar();
    c.actualizarNivelVoz(1.7);
    expect(c.usaNivelExterno, isTrue);
    expect(c.nivelVoz, 1.0, reason: 'se limita a 0..1');
  });

  test('al dejar de hablar se reinicia el nivel', () {
    c.hablar();
    c.actualizarNivelVoz(0.6);
    c.escuchar();
    expect(c.nivelVoz, 0);
    expect(c.usaNivelExterno, isFalse);
  });
}
