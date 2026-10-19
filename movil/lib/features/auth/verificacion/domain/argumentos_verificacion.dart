/// Por qué se pide el código de 6 dígitos (RF-05).
enum MotivoVerificacion {
  /// Recién creó la cuenta (RF-03 CA-8 / RF-05 CA-1): se verifica el correo.
  registro,

  /// Inició sesión en un celular que el Back no conoce (RF-04 CA-5).
  inicioSesion,
}

/// Lo que recibe la pantalla de verificación por la ruta `/verificacion`.
///
/// El registro (RF-03) navega enviando solo el correo como texto; el router
/// lo convierte con [ArgumentosVerificacion.desdeExtra].
class ArgumentosVerificacion {
  const ArgumentosVerificacion({required this.correo, required this.motivo});

  final String correo;
  final MotivoVerificacion motivo;

  /// Interpreta el `extra` de go_router. Devuelve null si no hay datos
  /// (por ejemplo, al reiniciar la app estando en /verificacion).
  static ArgumentosVerificacion? desdeExtra(Object? extra) => switch (extra) {
        ArgumentosVerificacion a => a,
        String correo when correo.isNotEmpty => ArgumentosVerificacion(
            correo: correo,
            motivo: MotivoVerificacion.registro,
          ),
        _ => null,
      };
}

/// RF-05 CA-2: "ju•••@correo.com". Deja ver las 2 primeras letras.
String enmascararCorreo(String correo) {
  final arroba = correo.indexOf('@');
  if (arroba <= 0) return correo;
  final usuario = correo.substring(0, arroba);
  final dominio = correo.substring(arroba);
  final visible = usuario.length <= 2 ? usuario.substring(0, 1) : usuario.substring(0, 2);
  return '$visible•••$dominio';
}
