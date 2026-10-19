import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_drawer.dart';
import '../widgets/floating_nav_bar.dart';

/// Contenedor raíz (Shell) de las pestañas Inicio, Juegos y Perfil (RF-10).
///
/// El router (`core/router/app_router.dart`) le entrega [navigationShell],
/// que contiene la pestaña activa y conserva el estado de las demás.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // CA-2: con el teclado virtual abierto la barra se oculta. Se lee aquí,
    // fuera del Scaffold, porque el Scaffold le quita el inset a su body.
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      drawer: const AppDrawer(),
      body: AppBackground(
        child: Stack(
          children: [
            Positioned.fill(child: navigationShell),

            // CA-1: barra fija en la base, solo en las pantallas de nivel
            // superior (las de profundidad se abren encima del shell).
            if (!tecladoAbierto)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: FloatingNavBar(
                    currentIndex: navigationShell.currentIndex,
                    onTabSelected: _irAPestana,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _irAPestana(int indice) {
    // Tocar la pestaña que ya está activa vuelve a su pantalla inicial.
    navigationShell.goBranch(
      indice,
      initialLocation: indice == navigationShell.currentIndex,
    );
  }
}
