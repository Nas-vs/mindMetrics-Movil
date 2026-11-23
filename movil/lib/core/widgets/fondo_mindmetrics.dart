import 'package:flutter/material.dart';

import '../../features/auth/compartido/presentation/fondo_auth.dart';
import '../tema/app_tema.dart';

/// Estructura visual de las pantallas de profundidad (RF-08, RF-11), igual a
/// la bienvenida de RF-01: imagen de fondo fija, velo blanco al 45 %, sin
/// AppBar y contenido centrado con ancho máximo de formulario.
///
/// Aplica [AppTema.claro] para que tarjetas, chips, campos y botones se vean
/// igual que en autenticación y bienvenida.
class FondoMindMetrics extends StatelessWidget {
  const FondoMindMetrics({
    super.key,
    required this.contenido,
    this.pie,
    this.alVolver,
  });

  /// Lo que se desplaza (normalmente una o varias `Card`).
  final Widget contenido;

  /// Fijo abajo, fuera del scroll (p. ej. el botón principal).
  final Widget? pie;

  /// Flecha de regreso. Si es null se usa `Navigator.maybePop`.
  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTema.claro(),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: Image(
                image: AssetImage(ImagenesAuth.fondo),
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.45)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppMedidas.margenPantalla),
                child: Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Volver',
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppColores.texto),
                          onPressed: alVolver ??
                              () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppMedidas.anchoMaximoFormulario,
                            ),
                            child: contenido,
                          ),
                        ),
                      ),
                    ),
                    if (pie != null) ...[
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppMedidas.anchoMaximoFormulario,
                        ),
                        child: SizedBox(width: double.infinity, child: pie),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Círculo con ícono blanco sobre el primario, como en la bienvenida.
class IconoCircular extends StatelessWidget {
  const IconoCircular(this.icono, {super.key, this.tamano = 96});
  final IconData icono;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        decoration: const BoxDecoration(
          color: AppColores.primario,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icono, size: tamano * .55, color: Colors.white),
      );
}

/// Título azul de marca (headlineSmall, `grafico2`, peso 800), como los de
/// las tarjetas de la bienvenida.
class TituloTarjeta extends StatelessWidget {
  const TituloTarjeta(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColores.grafico2,
              fontWeight: FontWeight.w800,
            ),
      );
}
