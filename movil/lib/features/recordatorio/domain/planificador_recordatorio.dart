/// Calcula QUÉ días y a QUÉ hora debe sonar el recordatorio (RF-22).
///
/// Es lógica pura (sin plugins ni Supabase) para poder probarla.
///
/// ¿Por qué se programan varios días sueltos y no una notificación que se
/// repite sola? Porque una notificación repetida tiene siempre el mismo
/// texto (y CA-2 pide textos variados) y porque así se puede cancelar SOLO
/// la de hoy cuando el usuario ya registró (CA-3).
abstract final class PlanificadorRecordatorio {
  /// Cuántos días se dejan programados. Se reprograman cada vez que se abre
  /// la app, así que solo dejan de llegar si no la abre en una semana.
  static const diasProgramados = 7;

  /// Fechas (hora local) en que debe sonar, empezando hoy.
  ///
  /// Hoy se incluye solo si la hora todavía no ha pasado y el usuario aún
  /// no ha registrado su ánimo (CA-3).
  static List<DateTime> proximasFechas({
    required DateTime ahora,
    required int hora,
    required int minuto,
    required bool registroHoy,
    int dias = diasProgramados,
  }) {
    final fechas = <DateTime>[];
    for (var i = 0; i < dias; i++) {
      final fecha = DateTime(ahora.year, ahora.month, ahora.day + i, hora, minuto);
      final esHoy = i == 0;
      if (esHoy && (registroHoy || !fecha.isAfter(ahora))) continue;
      fechas.add(fecha);
    }
    return fechas;
  }

  /// Id de la notificación de un día: AAAAMMDD (ej. 20261109).
  /// Así se puede cancelar la de un día concreto sin guardar ids.
  static int idParaFecha(DateTime fecha) =>
      fecha.year * 10000 + fecha.month * 100 + fecha.day;
}
