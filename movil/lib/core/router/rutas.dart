/// Rutas de la app (RF-10). Usar estas constantes en vez de escribir el
/// texto de la ruta a mano: `context.go(Rutas.juegos)`.
class Rutas {
  Rutas._(); // Solo constantes: no se instancia.

  // Sin sesión
  static const login = '/login';
  static const consentimiento = '/consentimiento';
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
  /// RF-08: registro rápido de ánimo (botón + y notificación de RF-22).
  static const encuesta = '/encuesta';

  /// RF-11: calendario emocional mensual.
  static const calendario = '/calendario';

  /// RF-22: configuración del recordatorio diario.
  static const recordatorio = '/recordatorio';

  /// Evaluación inicial conversando con la mascota (avatar por voz).
  static const avatar = '/avatar';

  /// RF-01: carrusel de bienvenida (solo la primera vez).
  static const bienvenida = '/bienvenida';

  /// Rutas a las que se puede entrar sin sesión.
  static const publicas = {
    bienvenida,
    login,
    consentimiento,
    registro,
    verificacion,
    recuperarContrasena,
  };
}

//test
