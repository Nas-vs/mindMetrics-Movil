import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/daily_recommendation.dart';
import '../widgets/stat_card.dart';
import 'daily_survey_screen.dart';

class HomeScreen extends StatelessWidget {
  // TODO: reemplazar por el nombre real del usuario autenticado.
  final String username;

  const HomeScreen({super.key, this.username = 'usuario'});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Botón menú hamburguesa ----------
          _BlueSquareButton(
            icon: Icons.menu_rounded,
            size: 64,
            iconSize: 44,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),

          const SizedBox(height: 70),

          // ---------- Saludo + botón encuesta diaria ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Hola, @$username',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              _BlueSquareButton(
                icon: Icons.add_rounded,
                size: 44,
                iconSize: 34,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DailySurveyScreen()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 70),

          // ---------- 3 cuadros de estadísticas ----------
          const Row(
            children: [
              Expanded(child: StatCard(title: 'Estimación\nde hoy', height: 95)),
              SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Estimación en base a registro', height: 95)),
              SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Número de\nDías activo', height: 95)),
            ],
          ),

          const SizedBox(height: 70),

          // ---------- Calendario + Recomendación diaria ----------
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: StatCard(title: 'Calendario', height: 190),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DailyRecommendation(),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Botón cuadrado azul con esquinas redondeadas (menú y "+").
class _BlueSquareButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  const _BlueSquareButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(size * 0.22),
      child: InkWell(
        borderRadius: BorderRadius.circular(size * 0.22),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }
}
