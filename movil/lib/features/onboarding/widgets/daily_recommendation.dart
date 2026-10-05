import 'package:flutter/material.dart';

import '../data/recommendations.dart';
import '../theme/app_colors.dart';

/// Ícono de taza + texto "Recomendación Diaria".
/// Al tocarlo muestra un consejo aleatorio.
class DailyRecommendation extends StatefulWidget {
  const DailyRecommendation({super.key});

  @override
  State<DailyRecommendation> createState() => _DailyRecommendationState();
}

class _DailyRecommendationState extends State<DailyRecommendation> {
  late final String _tip = Recommendations.random();

  void _showTip() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.coffee_rounded, size: 48, color: Color(0xFFE08A3C)),
            const SizedBox(height: 12),
            const Text(
              'Recomendación del día',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_tip, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _showTip,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFE9D6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.coffee_rounded,
                size: 56,
                color: Color(0xFFE08A3C),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Recomendación\nDiaria',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
