/// Rutas de la app (RF-10). Usar estas constantes en vez de escribir el
/// texto de la ruta a mano: `context.go(Rutas.juegos)`.
class Rutas {
  Rutas._(); // Solo constantes: no se instancia.

  // Sin sesión
  static const login = '/login';
  static const registro = '/registro';
  static const verificacion = '/verificacion';
  static const recuperarContrasena = '/recuperar-contrasena';

  // Solo con la sesión temporal del enlace del correo (RF-06)
  static const restablecerContrasena = '/restablecer-contrasena';

  // Pantallas de nivel superior: muestran la barra inferior (CA-1)
  static const inicio = '/inicio';
  static const juegos = '/juegos';
  static const perfil = '/perfil';

  // Pantallas de profundidad: se abren encima del shell, sin barra (CA-2)
  static const encuesta = '/encuesta';

  /// Rutas a las que se puede entrar sin sesión.
  static const publicas = {
    login,
    registro,
    verificacion,
    recuperarContrasena,
  };
}
