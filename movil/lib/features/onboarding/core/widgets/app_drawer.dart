import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/tema/app_tema.dart';
import '../../../auth/sesion/data/sesion_repositorio.dart';
import '../constants/app_colors.dart';

/// Menú lateral (Drawer) accesible desde el botón hamburguesa.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  /// Pide confirmación y cierra la sesión. No hace falta navegar: el router
  /// (RF-10) detecta que ya no hay sesión y lleva al inicio de sesión.
  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Para volver a entrar necesitarás tu contraseña y un código que '
          'te enviaremos al correo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await ref.read(sesionRepositorioProvider).cerrarSesion();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: const Color(0xFFF2F6F5),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Opciones con scroll: si la pantalla es pequeña o la letra del
            // celular es grande, no se desbordan y "Cerrar sesión" queda
            // siempre visible al final.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    color: AppColors.primaryTeal,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 36, color: AppColors.primaryTeal),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Menú Principal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'MindMetrics',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.home_rounded, color: AppColors.primaryTeal),
                    title: const Text('Inicio'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sports_esports_rounded, color: AppColors.primaryTeal),
                    title: const Text('Juegos y Actividades'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.poll_rounded, color: AppColors.primaryTeal),
                    title: const Text('Encuesta Diaria'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.insights_rounded, color: AppColors.primaryTeal),
                    title: const Text('Estadísticas'),
                    onTap: () => Navigator.pop(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_rounded, color: AppColors.textMuted),
                    title: const Text('Configuración'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColores.destructivo),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: AppColores.destructivo,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _cerrarSesion(context, ref),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
