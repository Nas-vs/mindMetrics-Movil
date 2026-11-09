import 'package:flutter/foundation.dart';

/// Qué está haciendo el avatar dentro de la conversación por voz.
///
/// Sigue el ciclo de un turno: el usuario habla ([escuchando]), el motor
/// procesa ([pensando]) y el avatar responde ([hablando]).
enum ActividadAvatar { inactivo, escuchando, pensando, hablando }

/// Tono con el que el avatar acompaña lo que dice o escucha.
///
/// El guion decide la emoción de cada pregunta: [empatico] para preguntas
/// sensibles, [alegre] para saludos y cierres.
enum EmocionAvatar { neutral, alegre, empatico }

/// Estado visible del avatar. Inmutable: el controlador crea uno nuevo
/// en cada cambio y la vista solo lo lee.
@immutable
class EstadoAvatar {
  const EstadoAvatar({
    this.actividad = ActividadAvatar.inactivo,
    this.emocion = EmocionAvatar.neutral,
  });

  static const inicial = EstadoAvatar();

  final ActividadAvatar actividad;
  final EmocionAvatar emocion;

  EstadoAvatar copyWith({ActividadAvatar? actividad, EmocionAvatar? emocion}) =>
      EstadoAvatar(
        actividad: actividad ?? this.actividad,
        emocion: emocion ?? this.emocion,
      );

  /// Texto para lectores de pantalla (TalkBack / VoiceOver).
  String get descripcion => switch (actividad) {
        ActividadAvatar.inactivo => 'en espera',
        ActividadAvatar.escuchando => 'escuchando',
        ActividadAvatar.pensando => 'pensando',
        ActividadAvatar.hablando => 'hablando',
      };

  @override
  bool operator ==(Object other) =>
      other is EstadoAvatar &&
      other.actividad == actividad &&
      other.emocion == emocion;

  @override
  int get hashCode => Object.hash(actividad, emocion);

  @override
  String toString() => 'EstadoAvatar($actividad, $emocion)';
}
