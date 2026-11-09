import 'dart:async';

/// Convierte los eventos del reconocedor de voz (resultados parciales,
/// estados y errores) en UNA respuesta: el texto dicho o `null`.
///
/// No depende del plugin para poder probarla sin micrófono. Reglas:
/// - Resultado final con texto → ese texto.
/// - Estado "done" sin resultado final → el último parcial (o `null`).
/// - Error de silencio o de "no entendí" → `null` (la sesión lo cuenta como
///   silencio y vuelve a preguntar).
/// - Cualquier otro error o [cancelar] → `null` y queda en [ultimoError].
class EscuchaUnaVez {
  final _completer = Completer<String?>();
  String _parcial = '';
  String? _ultimoError;

  /// Errores de speech_to_text que significan "no se oyó nada útil".
  static const erroresDeSilencio = {
    'error_no_match',
    'error_speech_timeout',
    'error_no_speech', // iOS
  };

  Future<String?> get futuro => _completer.future;
  bool get terminada => _completer.isCompleted;
  String? get ultimoError => _ultimoError;

  void alResultado(String palabras, {required bool esFinal}) {
    final texto = palabras.trim();
    if (texto.isNotEmpty) _parcial = texto;
    if (esFinal) _terminar(_parcial.isEmpty ? null : _parcial);
  }

  /// Estados de speech_to_text: 'listening', 'notListening', 'done'.
  void alEstado(String estado) {
    if (estado == 'done') _terminar(_parcial.isEmpty ? null : _parcial);
  }

  void alError(String mensaje) {
    if (!erroresDeSilencio.contains(mensaje)) _ultimoError = mensaje;
    _terminar(null);
  }

  void cancelar() => _terminar(null);

  void _terminar(String? texto) {
    if (!_completer.isCompleted) _completer.complete(texto);
  }
}
