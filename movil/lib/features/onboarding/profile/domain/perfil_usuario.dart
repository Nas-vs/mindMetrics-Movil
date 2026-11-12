/// Modelo de dominio del RF-23: datos del perfil del usuario autenticado.
class PerfilUsuario {
  const PerfilUsuario({
    required this.id,
    required this.nombreCompleto,
    required this.nickname,
    required this.correo,
    required this.creadoEn,
  });

  final String id;
  final String nombreCompleto;
  final String nickname;
  final String correo;
  final DateTime creadoEn;

  /// CA-1: Genera las iniciales a partir del nombre completo (máximo 2 letras).
  /// Ej: "Samuel Orozco" -> "SO", "Ana María" -> "AM", "Nasly" -> "N".
  String get iniciales {
    final partes = nombreCompleto
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      return partes[0].substring(0, 1).toUpperCase();
    }
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  /// CA-1: Formato legible para la fecha de registro en español.
  String get fechaRegistroFormateada {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final mes = meses[creadoEn.month - 1];
    return 'Miembro desde $mes de ${creadoEn.year}';
  }

  PerfilUsuario copyWith({
    String? id,
    String? nombreCompleto,
    String? nickname,
    String? correo,
    DateTime? creadoEn,
  }) {
    return PerfilUsuario(
      id: id ?? this.id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      nickname: nickname ?? this.nickname,
      correo: correo ?? this.correo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  factory PerfilUsuario.desdeSupabase({
    required Map<String, dynamic> fila,
    required String correo,
  }) {
    return PerfilUsuario(
      id: fila['id'] as String,
      nombreCompleto: fila['nombre_completo'] as String,
      nickname: fila['nickname'] as String,
      correo: correo,
      creadoEn: DateTime.parse(fila['creado_en'] as String).toLocal(),
    );
  }
}
