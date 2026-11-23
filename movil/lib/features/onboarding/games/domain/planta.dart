import 'package:flutter/material.dart';

/// Tipos de plantas disponibles para adoptar (RF-16 CA-1).
enum TipoPlanta {
  girasol(
    'Girasol',
    '🌻',
    'Resiliencia y luz en cada jornada',
    Color(0xFFFFB300),
  ),
  cactus(
    'Cactus',
    '🌵',
    'Fuerza serena en los momentos difíciles',
    Color(0xFF43A047),
  ),
  arbol(
    'Árbol pequeño',
    '🌳',
    'Crecimiento paciente con raíces firmes',
    Color(0xFF2E7D32),
  );

  const TipoPlanta(this.nombre, this.emoji, this.significado, this.color);

  final String nombre;
  final String emoji;
  final String significado;
  final Color color;
}

/// Decoraciones desbloqueables por hitos de racha (RF-16 CA-5).
enum DecoracionJardin {
  mariposa('Mariposa', '🦋', 7, 'Desbloqueada a los 7 días de racha'),
  banca('Banca', '🪑', 14, 'Desbloqueada a los 14 días de racha'),
  farol('Farol', '🏮', 30, 'Desbloqueada a los 30 días de racha');

  const DecoracionJardin(
    this.nombre,
    this.icono,
    this.diasRequeridos,
    this.descripcion,
  );

  final String nombre;
  final String icono;
  final int diasRequeridos;
  final String descripcion;
}

/// Modelo de la planta del usuario (RF-16 CA-1 y CA-3).
class Planta {
  const Planta({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.totalRiegos = 0,
    required this.fechaCreacion,
    required this.ultimoAcceso,
  });

  final String id;
  final String nombre;
  final TipoPlanta tipo;
  final int totalRiegos;
  final DateTime fechaCreacion;
  final DateTime ultimoAcceso;

  /// CA-3: Avanza una etapa cada 3 riegos, con un máximo de 7 etapas.
  int get etapa {
    final calculada = 1 + (totalRiegos ~/ 3);
    return calculada > 7 ? 7 : calculada;
  }

  /// Indica cuántos riegos le faltan para la siguiente etapa.
  int get riegosParaSiguienteEtapa {
    if (etapa >= 7) return 0;
    return 3 - (totalRiegos % 3);
  }

  /// Porcentaje de progreso de 0.0 a 1.0 hacia la madurez total (7 etapas = 18 riegos).
  double get progresoTotal {
    final progreso = totalRiegos / 18.0;
    return progreso > 1.0 ? 1.0 : progreso;
  }

  /// Retorna una copia con un riego adicional (CA-2).
  Planta regar() {
    return Planta(
      id: id,
      nombre: nombre,
      tipo: tipo,
      totalRiegos: totalRiegos + 1,
      fechaCreacion: fechaCreacion,
      ultimoAcceso: DateTime.now(),
    );
  }

  /// Convierte a Map para guardar en almacenamiento local.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'tipo': tipo.name,
      'totalRiegos': totalRiegos,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'ultimoAcceso': ultimoAcceso.toIso8601String(),
    };
  }

  /// Reconstruye la planta desde almacenamiento local.
  factory Planta.fromMap(Map<String, dynamic> map) {
    return Planta(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      tipo: TipoPlanta.values.byName(map['tipo'] as String),
      totalRiegos: map['totalRiegos'] as int? ?? 0,
      fechaCreacion: DateTime.parse(map['fechaCreacion'] as String),
      ultimoAcceso: DateTime.parse(map['ultimoAcceso'] as String),
    );
  }
}
