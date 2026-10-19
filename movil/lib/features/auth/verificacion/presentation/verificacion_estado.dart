import '../data/verificacion_repositorio.dart';

/// Estado inmutable de la pantalla de verificación (RF-05).
class VerificacionEstado {
  const VerificacionEstado({
    this.cargando = false,
    this.reenviando = false,
    this.intentosFallidos = 0,
    this.reenviosUsados = 0,
    this.segundosParaReenviar = 0,
    this.exito = false,
    this.descartada = false,
    this.error,
  });

  /// true mientras se valida el código.
  final bool cargando;

  /// true mientras se pide un código nuevo.
  final bool reenviando;

  /// Códigos incorrectos en esta sesión (CA-6). Cada aumento hace vibrar.
  final int intentosFallidos;

  /// Códigos reenviados en esta sesión (CA-5: máximo 3).
  final int reenviosUsados;

  /// Cuenta regresiva de "Reenviar en 00:59" (CA-5).
  final int segundosParaReenviar;

  /// Código correcto: ya hay sesión (CA-8).
  final bool exito;

  /// 3 fallos o código vencido: se vuelve al inicio de sesión (CA-7).
  final bool descartada;

  /// Error que no es "código incorrecto" (red, servidor, límite de correos).
  final ErrorVerificacion? error;

  /// Copia el estado. [error] no se conserva: un error se muestra una vez.
  VerificacionEstado copiar({
    bool? cargando,
    bool? reenviando,
    int? intentosFallidos,
    int? reenviosUsados,
    int? segundosParaReenviar,
    bool? exito,
    bool? descartada,
    ErrorVerificacion? error,
  }) =>
      VerificacionEstado(
        cargando: cargando ?? this.cargando,
        reenviando: reenviando ?? this.reenviando,
        intentosFallidos: intentosFallidos ?? this.intentosFallidos,
        reenviosUsados: reenviosUsados ?? this.reenviosUsados,
        segundosParaReenviar: segundosParaReenviar ?? this.segundosParaReenviar,
        exito: exito ?? this.exito,
        descartada: descartada ?? this.descartada,
        error: error,
      );
}
