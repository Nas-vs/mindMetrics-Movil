import '../data/consentimiento_repositorio.dart';
import '../domain/politica_privacidad.dart';

/// Estado inmutable de la pantalla de consentimiento informado (RF-02).
class ConsentimientoEstado {
  const ConsentimientoEstado({
    this.cargando = false,
    this.politica,
    this.error,
  });

  final bool cargando;
  final PoliticaPrivacidad? politica;
  final ErrorConsentimiento? error;
}
