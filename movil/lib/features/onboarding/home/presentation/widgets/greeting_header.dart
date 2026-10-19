import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/rutas.dart';
import '../../../core/constants/app_colors.dart';

/// Encabezado con saludo "Hola, @Usuario" y botón circular/cuadrado con "+".
class GreetingHeader extends StatelessWidget {
  final String username;

  const GreetingHeader({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Hola, @$username',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Botón de más (+) con esquinas redondeadas y sombra
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // Pantalla de profundidad: se abre sin barra inferior (RF-10 CA-2).
            onTap: () => context.push(Rutas.encuesta),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
