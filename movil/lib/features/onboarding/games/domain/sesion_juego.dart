/// Registro de la sesión de un juego (RF-15 CA-8).
class SesionJuego {
  const SesionJuego({
    required this.id,
    required this.juegoId,
    required this.animoInicial,
    required this.animoFinal,
    required this.duracionSegundos,
    required this.completado,
    required this.fecha,
  });

  final String id;
  final String juegoId;
  final int? animoInicial; // 1 a 5 (opcional CA-1)
  final int? animoFinal; // 1 a 5 (opcional CA-7)
  final int duracionSegundos;
  final bool completado;
  final DateTime fecha;

  /// Retorna si el ánimo mejoró tras la sesión (CA-7).
  bool get mejoroAnimo {
    if (animoInicial == null || animoFinal == null) return false;
    return animoFinal! > animoInicial!;
  }

  /// Mensaje amable que compara el ánimo antes y después (CA-7).
  String? get mensajeComparativo {
    if (animoInicial == null || animoFinal == null) return null;
    if (animoFinal! > animoInicial!) {
      return '¡Subiste de $animoInicial a $animoFinal! Nos alegra que te sientas mejor.';
    } else if (animoFinal == animoInicial) {
      return 'Mantuviste tu nivel de bienestar ($animoFinal/5).';
    } else {
      return 'Te diste un espacio para ti ($animoInicial → $animoFinal). Mañana será un nuevo día.';
    }
  }
}
