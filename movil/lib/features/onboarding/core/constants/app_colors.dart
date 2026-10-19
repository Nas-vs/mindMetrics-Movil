import 'package:flutter/material.dart';

/// Paleta de colores del módulo de Home / Juegos / Usuario (MindMetrics).
class AppColors {
  AppColors._();

  // Colores principales
  static const Color primaryTeal = Color(0xFF0A8594);
  static const Color accentOrange = Color(0xFFBA7324);

  // Fondos y superficies
  static const Color backgroundFallback = Color(0xFF9EABA2);
  static const Color cardBackground = Color(0xFFE4ECE9);
  static const Color cardTranslucent = Color(0xA6E4ECE9); // 65 % opacidad
  static const Color cardSolid = Color(0xEBE4ECE9); // 92 % opacidad

  // Textos
  static const Color textDark = Color(0xFF1E2524);
  static const Color textMuted = Color(0xFF4A5552);

  // Elementos de UI
  static const Color hamburgerGray = Color(0xFFBAC5C0);
  static const Color navBarTeal = Color(0xFF00828F);

  // Alias usados por main.dart (tema global de la app)
  static const Color primary = primaryTeal;
  static const Color background = backgroundFallback;
}
