/// Modelo de dominio del RF-02: versión vigente del consentimiento informado.
class PoliticaPrivacidad {
  const PoliticaPrivacidad({
    required this.version,
    required this.titulo,
    required this.contenido,
  });

  final String version;
  final String titulo;
  final String contenido;

  factory PoliticaPrivacidad.desdeMapa(Map<String, dynamic> mapa) {
    return PoliticaPrivacidad(
      version: (mapa['version'] as String).trim(),
      titulo: (mapa['titulo'] as String).trim(),
      contenido: (mapa['contenido'] as String).trim(),
    );
  }
}

//test
