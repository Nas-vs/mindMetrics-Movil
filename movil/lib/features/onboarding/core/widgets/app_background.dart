import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

/// Envuelve cualquier vista con el fondo de pantalla oficial `fondo_registro_movil`.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Imagen de fondo fija a toda pantalla
        Positioned.fill(
          child: Image.asset(
            AppAssets.fondoRegistroMovil,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(color: AppColors.backgroundFallback),
          ),
        ),
        // Contenido de la pantalla
        SafeArea(child: child),
      ],
    );
  }
}
