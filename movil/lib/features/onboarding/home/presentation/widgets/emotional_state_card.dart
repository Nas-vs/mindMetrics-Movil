import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Contenedor de la sección "Estado emocional".
/// Fondo traslúcido que alberga la tira semanal ([chartWidget]).
class EmotionalStateCard extends StatelessWidget {
  final Widget? chartWidget;
  final String subtitulo;
  final VoidCallback? onTap;

  const EmotionalStateCard({
    super.key,
    this.chartWidget,
    this.subtitulo = 'Última semana',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Estado emocional - $subtitulo',
            style: const TextStyle(
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
              BoxShadow(color: Colors.black12, offset: Offset(0, 3), blurRadius: 8),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: chartWidget ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
