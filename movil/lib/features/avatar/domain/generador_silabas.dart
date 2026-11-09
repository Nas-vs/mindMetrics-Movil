import 'dart:math' as math;

/// Simula el ritmo del habla cuando el motor de voz no entrega la
/// amplitud del audio (caso de `flutter_tts`, que solo avisa inicio/fin).
///
/// Produce sílabas de 110–220 ms con picos de intensidad variables y
/// pausas cortas ocasionales, a ~5 sílabas/s: el ritmo típico del español.
/// Si más adelante el TTS entrega amplitud o visemas reales, el
/// controlador recibe ese nivel y este generador deja de usarse.
class GeneradorSilabas {
  GeneradorSilabas({math.Random? aleatorio})
      : _rnd = aleatorio ?? math.Random();

  final math.Random _rnd;

  Duration _duracion = Duration.zero;
  Duration _transcurrido = Duration.zero;
  double _pico = 0;
  bool _pausa = true;
  bool _vocalRedonda = false;

  /// Nivel de voz actual entre 0 y 1.
  double nivel = 0;

  /// Si la sílaba actual usa una vocal redonda (o/u).
  bool get vocalRedonda => _vocalRedonda;

  /// Avanza [dt] y recalcula [nivel].
  double avanzar(Duration dt) {
    _transcurrido += dt;
    while (_transcurrido >= _duracion) {
      _transcurrido -= _duracion;
      _siguiente();
    }
    if (_pausa || _duracion == Duration.zero) {
      nivel = 0;
    } else {
      final fase = _transcurrido.inMicroseconds / _duracion.inMicroseconds;
      // Envolvente: abre rápido y cierra suave.
      nivel = _pico * math.sin(math.pi * math.pow(fase, 0.7));
    }
    return nivel;
  }

  void reiniciar() {
    _duracion = Duration.zero;
    _transcurrido = Duration.zero;
    _pausa = true;
    nivel = 0;
  }

  void _siguiente() {
    _pausa = !_pausa && _rnd.nextDouble() < 0.14;
    if (_pausa) {
      _duracion = Duration(milliseconds: 70 + _rnd.nextInt(110));
    } else {
      _duracion = Duration(milliseconds: 110 + _rnd.nextInt(110));
      _pico = 0.35 + _rnd.nextDouble() * 0.65;
      _vocalRedonda = _rnd.nextDouble() < 0.22;
    }
  }
}
