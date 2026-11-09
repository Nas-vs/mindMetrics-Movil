/// Elección del idioma para reconocer y para hablar, prefiriendo el español
/// de Colombia y cayendo a la variante de español más cercana.
const preferenciaEspanol = ['es-CO', 'es-419', 'es-US', 'es-MX', 'es-ES'];

String _clave(String id) => id.replaceAll('_', '-').toLowerCase();

/// Devuelve el id TAL CUAL lo reporta la plataforma (con "_" o "-"), o
/// `null` si no hay ninguna variante de español.
String? elegirIdioma(Iterable<String> disponibles, {String? delSistema}) {
  final porClave = {for (final d in disponibles) _clave(d): d};
  for (final p in preferenciaEspanol) {
    final hallado = porClave[_clave(p)];
    if (hallado != null) return hallado;
  }
  if (delSistema != null && _clave(delSistema).startsWith('es')) {
    return porClave[_clave(delSistema)] ?? delSistema;
  }
  for (final d in disponibles) {
    if (_clave(d).startsWith('es')) return d;
  }
  return null;
}
