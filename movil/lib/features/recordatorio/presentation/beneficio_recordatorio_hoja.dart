import 'package:flutter/material.dart';

/// RF-22 CA-1: explica el beneficio del recordatorio ANTES de pedir el
/// permiso del sistema. Devuelve true si el usuario quiere activarlo.
Future<bool> mostrarBeneficioRecordatorio(BuildContext context) async {
  final acepta = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final tema = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 48, color: tema.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                '¡Listo, tu primer registro!',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Registrar cómo te sientes todos los días es lo que te permite '
                'ver patrones en tu bienestar. ¿Quieres que te lo recordemos '
                'una vez al día? Si ya registraste ese día, no te molestamos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí, recuérdamelo'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ahora no'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return acepta ?? false;
}
