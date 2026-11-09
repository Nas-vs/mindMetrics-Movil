/// RF-22 CA-2: textos variados para la notificación.
///
/// El texto de cada día sale de la fecha, así que dos días seguidos nunca
/// repiten el mismo mensaje y el resultado es siempre el mismo para un día
/// dado (fácil de probar).
abstract final class MensajesRecordatorio {
  static const titulo = 'MindMetrics';

  static const textos = <String>[
    '¿Cómo estuvo tu día?',
    'Tómate un momento: ¿cómo te sientes hoy?',
    'Un registro rápido y listo. ¿Cómo va tu ánimo?',
    '¿Qué tal te fue hoy? Cuéntanos con un emoji.',
    'Escucharte también es cuidarte. ¿Cómo estás?',
    'Tu jardín emocional te espera. ¿Cómo te sientes?',
    'Antes de terminar el día: ¿cómo te sentiste?',
  ];

  /// Mensaje para una fecha concreta.
  static String paraFecha(DateTime fecha) {
    final dia = DateTime.utc(fecha.year, fecha.month, fecha.day);
    final diasDesdeEpoca = dia.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return textos[diasDesdeEpoca % textos.length];
  }
}
