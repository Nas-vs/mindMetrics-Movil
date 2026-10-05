import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra de navegación inferior en forma de "píldora" azul centrada.
/// 0 = Home, 1 = Actividades, 2 = Perfil
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.home_rounded,
    Icons.category_rounded, // 4 figuras
    Icons.person_rounded,
  ];

  static const _labels = ['Inicio', 'Actividades', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_icons.length, (i) {
                final selected = i == currentIndex;
                return Tooltip(
                  message: _labels[i],
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white24 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_icons[i], size: 40, color: AppColors.iconDark),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
