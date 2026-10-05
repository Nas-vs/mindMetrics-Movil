import '../data/registro_repositorio.dart';

/// Estado inmutable de la pantalla de registro.
class RegistroEstado {
  const RegistroEstado({
    this.cargando = false,
    this.exito = false,
    this.error,
  });

  /// true mientras se espera la respuesta del servidor (CA-7).
  final bool cargando;

  /// true cuando la cuenta se creó; dispara la navegación (CA-8).
  final bool exito;

  /// Último error ocurrido, o null si no hay.
  final ErrorRegistro? error;
}
