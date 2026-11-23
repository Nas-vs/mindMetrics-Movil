import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Cómo se mueve el personaje en reposo.
enum MovimientoAvatar {
  /// Sube y baja suavemente, con un leve balanceo (Nimbus, la nube).
  flotar,

  /// Se estira y se aplasta apoyado en el piso (Plip, la gota).
  rebotar,
}

/// Un personaje ("skin") del avatar.
///
/// Contrato de assets: cada personaje es una carpeta
/// `assets/avatar/<id>/` con las MISMAS capas SVG (ver [CapasAvatar.todas]),
/// todas con `viewBox="0 0 240 240"` para apilarlas sin calcular posiciones.
/// Agregar un personaje nuevo (gato, blob…) = crear su carpeta con esas
/// capas, declararla en `pubspec.yaml` y sumarlo a [PersonajesAvatar.todos].
@immutable
class PersonajeAvatar {
  const PersonajeAvatar({
    required this.id,
    required this.nombre,
    required this.movimiento,
    required this.colorAcento,
  });

  /// Nombre de la carpeta de assets. También se guarda como preferencia.
  final String id;

  /// Nombre que ve el usuario.
  final String nombre;

  final MovimientoAvatar movimiento;

  /// Color del anillo que aparece mientras escucha.
  final Color colorAcento;

  /// Ruta del asset de una capa, ej. `assets/avatar/nimbus/boca_media.svg`.
  String ruta(String capa) => 'assets/avatar/$id/$capa.svg';

  @override
  bool operator ==(Object other) => other is PersonajeAvatar && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Catálogo de personajes disponibles.
abstract final class PersonajesAvatar {
  static const nimbus = PersonajeAvatar(
    id: 'nimbus',
    nombre: 'Nimbus',
    movimiento: MovimientoAvatar.flotar,
    colorAcento: Color(0xFF8DBBD6),
  );

  static const plip = PersonajeAvatar(
    id: 'plip',
    nombre: 'Plip',
    movimiento: MovimientoAvatar.rebotar,
    colorAcento: Color(0xFF15919B),
  );

  static const todos = [nimbus, plip];

  /// Busca por id; si no existe (ej. preferencia vieja) devuelve Nimbus.
  static PersonajeAvatar porId(String? id) =>
      todos.firstWhere((p) => p.id == id, orElse: () => nimbus);
}
