import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Botón de menú hamburguesa con tres barras redondeadas y sombra sutil
/// idéntico al diseño de la imagen.
class HamburgerButton extends StatelessWidget {
  final VoidCallback onPressed;

  const HamburgerButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (index) {
            return Container(
              width: 44,
              height: 6.5,
              margin: EdgeInsets.only(bottom: index < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: AppColors.hamburgerGray,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 2.5,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
