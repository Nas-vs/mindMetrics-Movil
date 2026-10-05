import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Menú hamburguesa. Las opciones se definirán más adelante.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: AppColors.primary,
              child: const Text(
                'Menú',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // TODO: agregar las opciones del menú cuando se definan.
            const ListTile(
              leading: Icon(Icons.construction_rounded),
              title: Text('Próximamente...'),
            ),
          ],
        ),
      ),
    );
  }
}
