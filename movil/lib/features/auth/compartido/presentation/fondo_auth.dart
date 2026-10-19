import 'package:flutter/material.dart';

import '../../../../core/tema/app_tema.dart';

/// Rutas de las imágenes que comparten las pantallas de autenticación.
abstract final class ImagenesAuth {
  static const fondo = 'assets/images/fondo_registro_movil.jpg';
  static const logoBlanco = 'assets/images/logo_mindmetrics_blanco.png';
}

/// Estructura común de RF-04 (inicio de sesión) y RF-05 (verificación),
/// según el diseño de Figma: fondo fijo, logo arriba, tarjeta blanca en el
/// centro y un pie opcional abajo.
///
/// Aplica [AppTema.claro] para que los campos, botones y tarjeta se vean
/// igual que en el registro (RF-03), aunque el MaterialApp use otro tema.
class FondoAuth extends StatelessWidget {
  const FondoAuth({super.key, required this.tarjeta, this.pie});

  /// Contenido de la tarjeta blanca.
  final Widget tarjeta;

  /// Lo que va al final de la pantalla, fuera de la tarjeta.
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTema.claro(),
      child: Scaffold(
        body: Stack(
          children: [
            // Fondo fijo: no se desplaza con el contenido.
            const Positioned.fill(
              child: Image(
                image: AssetImage(ImagenesAuth.fondo),
                fit: BoxFit.cover,
              ),
            ),
            // Velo claro, igual que en el registro.
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.25)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, restricciones) => SingleChildScrollView(
                  padding: const EdgeInsets.all(AppMedidas.margenPantalla),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    // Ocupa al menos toda la pantalla, para que el pie quede
                    // abajo; si el teclado reduce el espacio, se desplaza.
                    constraints: BoxConstraints(
                      minHeight: restricciones.maxHeight -
                          AppMedidas.margenPantalla * 2,
                    ),
                    child: IntrinsicHeight(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppMedidas.anchoMaximoFormulario,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(flex: 2),
                              const LogoMindMetrics(),
                              const SizedBox(height: 32),
                              Card(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(AppMedidas.relleno),
                                  child: tarjeta,
                                ),
                              ),
                              const Spacer(flex: 3),
                              if (pie != null) ...[
                                const SizedBox(height: 24),
                                pie!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo con el nombre, como en el diseño.
///
/// Mientras no exista el PNG del logo a color, se tiñe el logo blanco con
/// el azul de la marca y el nombre se escribe con texto.
class LogoMindMetrics extends StatelessWidget {
  const LogoMindMetrics({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MindMetrics',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            ImagenesAuth.logoBlanco,
            height: 64,
            color: AppColores.grafico2,
          ),
          const SizedBox(width: 8),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Mind',
                  style: TextStyle(
                    color: AppColores.grafico2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: 'Metrics',
                  style: TextStyle(
                    color: AppColores.primario,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            style: TextStyle(fontSize: 34, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}

/// Botón principal con el logo blanco al lado del texto, como en el diseño
/// (y en el registro). Mientras [cargando] es true se deshabilita y muestra
/// un indicador.
class BotonConLogo extends StatelessWidget {
  const BotonConLogo({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.logoAntes = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  /// false: "Texto [logo]" (inicio de sesión). true: "[logo] Texto" (código).
  final bool logoAntes;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      ImagenesAuth.logoBlanco,
      height: 28,
      excludeFromSemantics: true,
    );
    return FilledButton(
      onPressed: cargando ? null : onPressed,
      child: cargando
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColores.sobrePrimario,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logoAntes) ...[logo, const SizedBox(width: 10)],
                Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
                if (!logoAntes) ...[const SizedBox(width: 10), logo],
              ],
            ),
    );
  }
}

/// Etiqueta encima del campo, igual que en el registro.
class CampoConEtiqueta extends StatelessWidget {
  const CampoConEtiqueta({
    super.key,
    required this.etiqueta,
    required this.child,
  });

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColores.texto,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Enlace subrayado en el color primario ("¿Olvidó su contraseña?",
/// "Reenviar código"). Con [onPressed] null se ve atenuado.
class EnlaceAuth extends StatelessWidget {
  const EnlaceAuth({super.key, required this.texto, required this.onPressed});

  final String texto;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColores.primario,
        minimumSize: const Size(48, 48), // área táctil mínima
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
