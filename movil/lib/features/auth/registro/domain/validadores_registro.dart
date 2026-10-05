
class ValidadoresRegistro {
  ValidadoresRegistro._(); // Solo métodos estáticos: no se instancia.

  /// Igual al CHECK `perfiles_nombre_completo_formato`.
  static final _nombre = RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]+$');
  static final _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _espacio = RegExp(r'\s');

  static const edadMinima = 18;

  static String? nombreCompleto(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu nombre completo';
    if (v.length > 60) return 'Máximo 60 caracteres';
    if (!_nombre.hasMatch(v)) return 'Solo letras, espacios y tildes';
    return null;
  }


  /// La unicidad la verifica la RPC `nickname_disponible` en el repositorio.
  static String? nickname(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa un nickname';
    if (_espacio.hasMatch(v)) return 'El nickname no puede tener espacios';
    if (v.length < 3 || v.length > 20) return 'Debe tener entre 3 y 20 caracteres';
    return null;
  }

  static String? correo(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    return _correo.hasMatch(v) ? null : 'Correo no válido';
  }

  /// Reglas de la contraseña, en el orden en que se muestran (CA-4).
  /// El backend exige 8 caracteres + mayúscula + minúscula + número;
  /// el carácter especial es una regla adicional del front.
  static Map<String, bool> reglasContrasena(String p) => {
        'Mínimo 8 caracteres': p.length >= 8,
        'Una letra mayúscula': p.contains(RegExp(r'[A-Z]')),
        'Una letra minúscula': p.contains(RegExp(r'[a-z]')),
        'Un número': p.contains(RegExp(r'\d')),
        'Un carácter especial': p.contains(RegExp(r'[^A-Za-z0-9]')),
      };

  static String? contrasena(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    return reglasContrasena(v).values.every((cumple) => cumple)
        ? null
        : 'La contraseña no cumple todas las reglas';
  }

  /// `confirmar_contrasena` no se envía al backend (solo se valida aquí).
  static String? confirmarContrasena(String? valor, String original) {
    if ((valor ?? '').isEmpty) return 'Confirma tu contraseña';
    return valor == original ? null : 'Las contraseñas no coinciden';
  }

  /// Fecha más reciente permitida: hoy menos 18 años.
  /// [hoy] es inyectable para que las pruebas sean deterministas.
  static DateTime fechaLimite([DateTime? hoy]) {
    final h = hoy ?? DateTime.now();
    return DateTime(h.year - edadMinima, h.month, h.day);
  }

  /// Misma regla que el trigger `crear_perfil_inicial`:
  /// se rechaza si fecha_nacimiento > hoy - 18 años.
  static String? fechaNacimiento(DateTime? fecha, [DateTime? hoy]) {
    if (fecha == null) return 'Selecciona tu fecha de nacimiento';
    return fecha.isAfter(fechaLimite(hoy))
        ? 'Debes tener $edadMinima años o más'
        : null;
  }
}
