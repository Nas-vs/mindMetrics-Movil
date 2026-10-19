import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';

/// Barra de navegación flotante en forma de píldora con los 3 logos personalizados.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.navBarTeal,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavBarItem(
            assetPath: AppAssets.logoMindmetrics,
            fallbackIcon: Icons.psychology_rounded,
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          _NavBarItem(
            assetPath: AppAssets.logoJuegos,
            fallbackIcon: Icons.sports_esports_rounded,
            isSelected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          _NavBarItem(
            assetPath: AppAssets.logoPersona,
            fallbackIcon: Icons.person_rounded,
            isSelected: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.assetPath,
    required this.fallbackIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedScale(
          scale: isSelected ? 1.08 : 0.95,
          duration: const Duration(milliseconds: 200),
          child: Image.asset(
            assetPath,
            width: 32,
            height: 32,
            color: Colors.white,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Icon(fallbackIcon, size: 30, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
