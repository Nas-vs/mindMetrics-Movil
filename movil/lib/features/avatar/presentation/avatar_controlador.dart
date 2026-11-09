import 'package:flutter/foundation.dart';

import '../domain/estado_avatar.dart';

/// Controla lo que hace el avatar. Lo maneja quien orquesta la
/// conversación (bot de voz / guion); la vista `AvatarMascota` solo escucha.
///
/// Uso típico en un turno:
/// ```dart
/// controlador.hablar(emocion: EmocionAvatar.empatico); // TTS: inicio
/// controlador.escuchar();                              // STT: abre micrófono
/// controlador.pensar();                                // envía al motor
/// controlador.detener();                               // fin del turno
/// ```
class AvatarControlador extends ChangeNotifier {
  AvatarControlador({EstadoAvatar inicial = EstadoAvatar.inicial})
      : _estado = inicial;

  EstadoAvatar _estado;
  EstadoAvatar get estado => _estado;

  double _nivelVoz = 0;

  /// Nivel de voz real (0..1) si el motor de voz lo entrega.
  double get nivelVoz => _nivelVoz;

  bool _nivelExterno = false;

  /// `true` cuando alguien está enviando la amplitud real con
  /// [actualizarNivelVoz]; si es `false`, la vista simula el ritmo.
  bool get usaNivelExterno => _nivelExterno;

  void escuchar() => _cambiar(actividad: ActividadAvatar.escuchando);

  void pensar() => _cambiar(actividad: ActividadAvatar.pensando);

  /// Empieza a hablar. [emocion] es la del fragmento del guion; si es
  /// `null` conserva la actual.
  void hablar({EmocionAvatar? emocion}) =>
      _cambiar(actividad: ActividadAvatar.hablando, emocion: emocion);

  /// Vuelve a reposo conservando la emoción.
  void detener() => _cambiar(actividad: ActividadAvatar.inactivo);

  void cambiarEmocion(EmocionAvatar emocion) => _cambiar(emocion: emocion);

  /// Amplitud real del audio (0..1), ej. desde el reproductor del TTS.
  /// Se ignora si el avatar no está hablando.
  void actualizarNivelVoz(double nivel) {
    if (_estado.actividad != ActividadAvatar.hablando) return;
    final nuevo = nivel.clamp(0.0, 1.0).toDouble();
    _nivelExterno = true;
    if (nuevo == _nivelVoz) return;
    _nivelVoz = nuevo;
    notifyListeners();
  }

  void _cambiar({ActividadAvatar? actividad, EmocionAvatar? emocion}) {
    final nuevo = _estado.copyWith(actividad: actividad, emocion: emocion);
    if (nuevo == _estado) return;
    if (nuevo.actividad != ActividadAvatar.hablando) {
      _nivelVoz = 0;
      _nivelExterno = false;
    }
    _estado = nuevo;
    notifyListeners();
  }
}
