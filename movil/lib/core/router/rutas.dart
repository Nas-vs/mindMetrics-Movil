/// Rutas de la app (RF-10). Usar estas constantes en vez de escribir el
/// texto de la ruta a mano: `context.go(Rutas.juegos)`.
class Rutas {
  Rutas._(); // Solo constantes: no se instancia.

  // Sin sesión
  static const registro = '/registro';
  static const verificacion = '/verificacion';

  // Pantallas de nivel superior: muestran la barra inferior (CA-1)
  static const inicio = '/inicio';
  static const juegos = '/juegos';
  static const perfil = '/perfil';

  // Pantallas de profundidad: se abren encima del shell, sin barra (CA-2)
  static const encuesta = '/encuesta';

  /// Rutas a las que se puede entrar sin sesión.
  /// Cuando exista el login (RF-04) se agrega aquí.
  static const publicas = {registro, verificacion};
}
