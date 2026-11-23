import 'package:flutter/material.dart';

import '../../../../animo/domain/registro_animo.dart';
import '../../../../calendario/calendario_emocional.dart' show colorNivel;
import '../../../core/constants/app_colors.dart';
import '../../data/models/home_summary_model.dart';

/// Tira lunes–domingo de la última semana registrada. Usa los mismos
/// colores por nivel que el calendario (RF-11) y acompaña cada barra con su
/// emoji para no depender solo del color.
class SemanaEmocional extends StatelessWidget {
  const SemanaEmocional({super.key, required this.dias, required this.hoy});

  final List<DiaSemana> dias;
  final DateTime hoy;

  static const _letras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    if (!dias.any((d) => d.nivel != null)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, color: AppColors.primaryTeal, size: 32),
              SizedBox(height: 8),
              Text(
                'Aún no hay registros de ánimo.\nToca + para registrar cómo te sientes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final d in dias) Expanded(child: _columna(d))],
      ),
    );
  }

  Widget _columna(DiaSemana d) {
    final nivel = d.nivel;
    final esHoy = DateUtils.isSameDay(d.fecha, hoy);
    final animo = nivel == null ? null : NivelAnimo.de(nivel);

    return Semantics(
      label: '${d.fecha.day}, ${animo?.etiqueta ?? 'sin registro'}',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                animo?.emoji ?? '·',
                style: TextStyle(
                  fontSize: animo == null ? 18 : 17,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 18,
                  height: nivel == null ? 4 : c.maxHeight * nivel / 5,
                  decoration: BoxDecoration(
                    color: nivel == null
                        ? AppColors.hamburgerGray
                        : colorNivel(nivel).withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _letras[d.fecha.weekday - 1],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: esHoy ? AppColors.primaryTeal : AppColors.textDark,
            ),
          ),
          Text(
            '${d.fecha.day}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: esHoy ? FontWeight.w800 : FontWeight.w500,
              color: esHoy ? AppColors.primaryTeal : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
