import 'dart:math';

/// Lista de consejos que se muestran aleatoriamente como "Recomendación diaria".
/// Más adelante se puede reemplazar por datos de una API o base de datos.
class Recommendations {
  Recommendations._();

  static const List<String> tips = [
    'Toma al menos 8 vasos de agua hoy.',
    'Haz una pausa de 5 minutos cada hora para estirarte.',
    'Intenta dormir entre 7 y 8 horas esta noche.',
    'Sal a caminar 20 minutos al aire libre.',
    'Respira profundo 5 veces antes de empezar una tarea difícil.',
    'Escribe 3 cosas por las que estés agradecido hoy.',
    'Reduce el uso del celular una hora antes de dormir.',
    'Come al menos una porción de fruta hoy.',
  ];

  static String random() => tips[Random().nextInt(tips.length)];
}
