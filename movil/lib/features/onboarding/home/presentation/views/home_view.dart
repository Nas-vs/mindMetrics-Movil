import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/hamburger_button.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/emotional_state_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/stat_card.dart';

/// Vista principal de Home (MVVM).
class HomeView extends StatelessWidget {
  final HomeViewModel viewModel;

  const HomeView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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

              // Fila con los dos primeros cuadros de estado
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Estado de hoy',
                      value: viewModel.estadoHoy,
                      valueColor: AppColors.primaryTeal,
                      height: 100,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: StatCard(
                      title: 'Registro estimado',
                      value: viewModel.registroEstimado,
                      valueColor: AppColors.accentOrange,
                      height: 100,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Cuadro ancho completo: Racha de días jugados
              StatCard(
                title: 'Racha de días jugados',
                value: '${viewModel.rachaDias} ${viewModel.rachaTexto}',
                valueColor: AppColors.primaryTeal,
                height: 105,
              ),

              const SizedBox(height: 28),

              // Estado emocional - Última semana
              const EmotionalStateCard(),

              // Espacio inferior para no chocar con el FloatingNavBar flotante
              const SizedBox(height: 110),
            ],
          ),
        );
      },
    );
  }
}
