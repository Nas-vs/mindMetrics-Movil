/// Configuración del recordatorio diario (RF-22).
///
/// Por ahora se guarda en el celular. Cuando exista el Back de RF-22
/// (Samuel), el repositorio también la sincronizará con Supabase sin que
/// esta clase cambie.
class PreferenciasRecordatorio {
  const PreferenciasRecordatorio({
    this.activo = false,
    this.hora = 20,
    this.minuto = 0,
    this.beneficioExplicado = false,
    this.ultimoDiaRegistrado,
  });

  /// El usuario quiere recibir el recordatorio.
  final bool activo;

  /// Hora local del recordatorio (0–23). Por defecto 8:00 p. m.
  final int hora;
  final int minuto;

  /// CA-1: ya se le explicó el beneficio después de su primer registro.
  /// Evita volver a mostrarle la explicación en cada registro.
  final bool beneficioExplicado;

  /// Último día (AAAAMMDD) en que la app vio un registro de ánimo. Así la
  /// notificación de hoy no vuelve a programarse aunque no haya internet
  /// para consultar Supabase (CA-3 sin conexión).
  final int? ultimoDiaRegistrado;

  PreferenciasRecordatorio copyWith({
    bool? activo,
    int? hora,
    int? minuto,
    bool? beneficioExplicado,
    int? ultimoDiaRegistrado,
  }) {
    return PreferenciasRecordatorio(
      activo: activo ?? this.activo,
      hora: hora ?? this.hora,
      minuto: minuto ?? this.minuto,
      beneficioExplicado: beneficioExplicado ?? this.beneficioExplicado,
      ultimoDiaRegistrado: ultimoDiaRegistrado ?? this.ultimoDiaRegistrado,
    );
  }

  Map<String, Object> toJson() => {
        'activo': activo,
        'hora': hora,
        'minuto': minuto,
        'beneficio_explicado': beneficioExplicado,
        'ultimo_dia_registrado': ?ultimoDiaRegistrado,
      };

  factory PreferenciasRecordatorio.fromJson(Map<String, dynamic> json) {
    return PreferenciasRecordatorio(
      activo: json['activo'] as bool? ?? false,
      hora: json['hora'] as int? ?? 20,
      minuto: json['minuto'] as int? ?? 0,
      beneficioExplicado: json['beneficio_explicado'] as bool? ?? false,
      ultimoDiaRegistrado: json['ultimo_dia_registrado'] as int?,
    );
  }

  /// "8:00 p. m." para mostrar en pantalla.
  String get horaTexto {
    final h12 = hora % 12 == 0 ? 12 : hora % 12;
    final mm = minuto.toString().padLeft(2, '0');
    return '$h12:$mm ${hora < 12 ? 'a. m.' : 'p. m.'}';
  }
}
