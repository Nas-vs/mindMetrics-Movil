/// Datos que el usuario escribe en el formulario de registro (RF-03).
///
/// Es Dart puro: no depende de Flutter ni de Supabase, así que se puede
/// probar sin emulador.
class DatosRegistro {
  const DatosRegistro({
    required this.nombreCompleto,
    required this.nickname,
    required this.correo,
    required this.contrasena,
    required this.fechaNacimiento,
    required this.versionPolitica,
  });

  final String nombreCompleto;
  final String nickname;
  final String correo;
  final String contrasena;
  final DateTime fechaNacimiento;

  /// Versión del consentimiento que el usuario aceptó en RF-02 (ej. '1.0').
  final String versionPolitica;

  /// Correo normalizado: sin espacios y en minúsculas (RN-03).
  String get correoNormalizado => correo.trim().toLowerCase();

  /// Metadatos que viajan en `signUp(data: ...)`.
  ///
  /// Las claves deben coincidir EXACTAMENTE con lo que leen los triggers:
  /// - `crear_perfil_inicial` (RF-03, Juliana): nombre_completo, nickname, fecha_nacimiento
  /// - `registrar_consentimiento_inicial` (RF-02, Nasly): acepta_datos_sensibles, version_politica
  Map<String, dynamic> aMetadatos() => {
        'nombre_completo': nombreCompleto.trim(),
        'nickname': nickname.trim(),
        'fecha_nacimiento': _aIsoFecha(fechaNacimiento),
        'acepta_datos_sensibles': true,
        'version_politica': versionPolitica,
      };

  /// AAAA-MM-DD, el formato que PostgreSQL convierte a `date`.
  static String _aIsoFecha(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';
}
