import 'package:flutter/material.dart';
import '../../../core/widgets/hamburger_button.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Vista de la sección de Perfil / Usuario (MVVM).
class ProfileView extends StatelessWidget {
  final ProfileViewModel viewModel;

  const ProfileView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Botón de menú hamburguesa
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: HamburgerButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const Spacer(),
            // Espacio inferior para el FloatingNavBar
            const SizedBox(height: 110),
          ],
        );
      },
    );
  }
}
