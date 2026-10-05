import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cuadro gris reutilizable (placeholder) donde luego se mostrará
/// información de estadísticas, encuestas y juegos.
class StatCard extends StatelessWidget {
  final String title;
  final Widget? child; // Contenido futuro (ej. un número o gráfico)
  final double? height;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    this.child,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: child ??
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
        ),
      ),
    );
  }
}
