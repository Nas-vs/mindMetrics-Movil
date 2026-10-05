import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';
import '../widgets/custom_bottom_nav.dart';
import 'activities_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Contenedor principal: contiene el menú hamburguesa (drawer),
/// la barra inferior y cambia entre Home, Actividades y Perfil.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _pages = [
    HomeScreen(),
    ActivitiesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
