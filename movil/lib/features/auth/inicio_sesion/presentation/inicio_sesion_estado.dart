import '../data/inicio_sesion_repositorio.dart';

/// Estado inmutable de la pantalla de inicio de sesión.
class InicioSesionEstado {
  const InicioSesionEstado({
    this.cargando = false,
    this.resultado,
    this.error,
  });

  /// true mientras se espera la respuesta (CA-3).
  final bool cargando;

  /// Cuando no es null, la vista navega (CA-4 / CA-5).
  final ResultadoInicioSesion? resultado;

  /// Último error ocurrido, o null si no hay.
  final ErrorInicioSesion? error;
}
