import 'package:flutter/material.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../games/presentation/viewmodels/games_viewmodel.dart';
import '../../../games/presentation/views/games_view.dart';
import '../../../home/presentation/viewmodels/home_viewmodel.dart';
import '../../../home/presentation/views/home_view.dart';
import '../../../profile/presentation/viewmodels/profile_viewmodel.dart';
import '../../../profile/presentation/views/profile_view.dart';
import '../viewmodels/main_shell_viewmodel.dart';
import '../widgets/floating_nav_bar.dart';

/// Contenedor raíz (Shell) que alberga el Drawer, la barra flotante y la navegación entre vistas.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final MainShellModel _shellViewModel;
  late final HomeViewModel _homeViewModel;
  late final GamesViewModel _gamesViewModel;
  late final ProfileViewModel _profileViewModel;

  @override
  void initState() {
    super.initState();
    _shellViewModel = MainShellModel();
    _homeViewModel = HomeViewModel();
    _gamesViewModel = GamesViewModel();
    _profileViewModel = ProfileViewModel();
  }

  @override
  void dispose() {
    _shellViewModel.dispose();
    _homeViewModel.dispose();
    _gamesViewModel.dispose();
    _profileViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: AppBackground(
        child: ListenableBuilder(
          listenable: _shellViewModel,
          builder: (context, _) {
            return Stack(
              children: [
                // Vistas con preservación de estado (IndexedStack)
                IndexedStack(
                  index: _shellViewModel.currentIndex,
                  children: [
                    HomeView(viewModel: _homeViewModel),
                    GamesView(viewModel: _gamesViewModel),
                    ProfileView(viewModel: _profileViewModel),
                  ],
                ),

                // Barra de navegación flotante centrada en la parte inferior
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: FloatingNavBar(
                      currentIndex: _shellViewModel.currentIndex,
                      onTabSelected: _shellViewModel.selectTab,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
