import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/rutas.dart';
import '../../../../animo/data/registro_animo_repositorio.dart';
import '../../../../inicio/recomendacion/recomendacion_dia.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/hamburger_button.dart';
import '../../data/models/home_summary_model.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/emotional_state_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/semana_emocional.dart';
import '../widgets/stat_card.dart';

/// Vista principal de Home (MVVM).
class HomeView extends StatelessWidget {
  final HomeViewModel viewModel;

  const HomeView({super.key, required this.viewModel});

  /// Riesgo 1 (verde) … 5 (rojo). Tonos oscuros para contraste sobre la
  /// tarjeta clara (texto, no relleno).
  static Color colorRiesgo(int? nivel) => switch (nivel) {
        1 => const Color(0xFF15803D),
        2 => const Color(0xFF4D7C0F),
        3 => const Color(0xFFB45309),
        4 => const Color(0xFFC2410C),
        5 => const Color(0xFFB91C1C),
        _ => AppColors.accentOrange,
      };

  Future<void> _abrirYRecargar(BuildContext context, String ruta) async {
    await context.push(ruta);
    await viewModel.loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final evaluacion = viewModel.evaluacion;
        return RefreshIndicator(
          color: AppColors.primaryTeal,
          onRefresh: viewModel.loadSummary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Botón de menú hamburguesa
                HamburgerButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),

                const SizedBox(height: 24),

                // Saludo y botón de encuesta (+)
                GreetingHeader(
                  username: viewModel.username,
                  fecha: viewModel.fechaActual,
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    // RF-08: ánimo registrado hoy
                    Expanded(
                      child: StatCard(
                        title: 'Estado de hoy',
                        value: viewModel.estadoHoy,
                        valueColor: AppColors.primaryTeal,
                        height: 100,
                        onTap: () => _abrirYRecargar(context, Rutas.encuesta),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Motor: último nivel de riesgo (nivel_riesgo_actual)
                    Expanded(
                      child: StatCard(
                        title: 'Resultado evaluación',
                        value: viewModel.resultadoEvaluacion,
                        valueColor: colorRiesgo(evaluacion.nivel),
                        height: 100,
                        onTap: () {
                          if (evaluacion.estado == EstadoEvaluacion.pendiente) {
                            _abrirYRecargar(context, Rutas.avatar);
                          } else {
                            _mostrarDetalleEvaluacion(context, evaluacion);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Días seguidos con registro de ánimo
                StatCard(
                  title: 'Racha de registros',
                  value: viewModel.racha,
                  valueColor: AppColors.primaryTeal,
                  height: 105,
                ),

                const SizedBox(height: 28),

                // RF-09: recomendación del día (cambia al registrar el ánimo)
                RecomendacionDiaTarjeta(recargar: animoGuardado),

                const SizedBox(height: 28),

                // RF-11: última semana registrada; al tocarla abre el mes
                EmotionalStateCard(
                  subtitulo: viewModel.tituloSemana,
                  onTap: () => _abrirYRecargar(context, Rutas.calendario),
                  chartWidget: viewModel.cargandoPrimeraVez
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primaryTeal),
                        )
                      : SemanaEmocional(dias: viewModel.semana, hoy: viewModel.hoy),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _abrirYRecargar(context, Rutas.calendario),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Ver calendario'),
                  ),
                ),

                // Espacio inferior para no chocar con el FloatingNavBar flotante
                const SizedBox(height: 110),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarDetalleEvaluacion(BuildContext context, ResultadoEvaluacion r) {
    final texto = switch (r.estado) {
      EstadoEvaluacion.listo => [
          'Nivel ${r.nivel} de 5 (${r.etiqueta!.toLowerCase()}).',
          r.origen == 'encuesta_diaria'
              ? 'Calculado con tus registros diarios.'
              : 'Calculado con tu evaluación inicial.',
          if (r.calculadoEn != null)
            'Última actualización: ${HomeViewModel.formatearFechaLarga(r.calculadoEn!)}.',
        ].join('\n'),
      EstadoEvaluacion.calculando =>
        'Tu evaluación inicial está guardada. El resultado aparece aquí cuando '
            'termine el cálculo; desliza hacia abajo para actualizar.',
      _ => 'No pudimos consultar tu resultado. Revisa tu conexión e inténtalo de nuevo.',
    };

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.cardBackground,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.textoCorto,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colorRiesgo(r.nivel),
              ),
            ),
            const SizedBox(height: 8),
            Text(texto, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
            const SizedBox(height: 12),
            const Text(
              'Este resultado es orientativo y no reemplaza un diagnóstico profesional.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if ((r.nivel ?? 0) >= 4) ...[
              const SizedBox(height: 8),
              const Text(
                'Te recomendamos hablar con un profesional de salud mental.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
