import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Contenedor de la sección "Estado emocional - Última semana".
/// Posee un fondo traslúcido estilizado listo para albergar gráficos o métricas futuras.
class EmotionalStateCard extends StatelessWidget {
  final Widget? chartWidget;

  const EmotionalStateCard({super.key, this.chartWidget});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Estado emocional - Última semana',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.cardTranslucent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: chartWidget ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}
