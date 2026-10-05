import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pantalla de la encuesta diaria (placeholder).
class DailySurveyScreen extends StatelessWidget {
  const DailySurveyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encuesta diaria'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Aquí irá la encuesta diaria',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
