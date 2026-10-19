import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_background.dart';

/// Pantalla para la encuesta diaria abierta por el botón (+).
class DailySurveyView extends StatelessWidget {
  const DailySurveyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardSolid,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, size: 54, color: AppColors.primaryTeal),
                      SizedBox(height: 16),
                      Text(
                        'Encuesta Diaria',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Aquí se desplegarán las preguntas de la encuesta diaria para registrar tu estado emocional.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                      ),
                    ],
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
