import 'package:flutter/material.dart';

/// Objetivos terapéuticos de los juegos (RF-14 CA-1 y CA-2).
enum ObjetivoJuego {
  relajarme('Relajarme', Icons.spa_rounded, Color(0xFF4DB6AC)),
  pensarDistinto(
    'Pensar distinto',
    Icons.psychology_rounded,
    Color(0xFF7E57C2),
  ),
  conocerEmociones(
    'Conocer mis emociones',
    Icons.favorite_rounded,
    Color(0xFFEF5350),
  ),
  constancia('Constancia', Icons.eco_rounded, Color(0xFF66BB6A));

  const ObjetivoJuego(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}

/// Modelo que representa un juego en el catálogo (RF-14 CA-1).
class Juego {
  const Juego({
    required this.id,
    required this.nombre,
    required this.descripcionCorta,
    required this.duracionAproximada,
    required this.objetivo,
    required this.icono,
    required this.colorFondo,
    this.recomendado = false,
  });

  final String id;
  final String nombre;
  final String descripcionCorta;
  final String duracionAproximada;
  final ObjetivoJuego objetivo;
  final IconData icono;
  final Color colorFondo;
  final bool recomendado;

  /// Permite crear una copia marcando si es el recomendado del día (CA-3).
  Juego copyWith({bool? recomendado}) {
    return Juego(
      id: id,
      nombre: nombre,
      descripcionCorta: descripcionCorta,
      duracionAproximada: duracionAproximada,
      objetivo: objetivo,
      icono: icono,
      colorFondo: colorFondo,
      recomendado: recomendado ?? this.recomendado,
    );
  }
}
