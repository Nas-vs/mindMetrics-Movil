import 'package:flutter/material.dart';

/// Cómo quiere responder el usuario la encuesta.
enum ModoConversacion { voz, texto, formulario }

/// Explica qué pasa con la voz ANTES de abrir el micrófono y deja elegir.
///
/// Es un dato sensible (salud mental): el usuario debe saber que el
/// reconocimiento lo hace Google (Android) o Apple (iOS) y que siempre puede
/// escribir o usar el formulario clásico.
Future<ModoConversacion?> pedirModoConversacion(BuildContext context, {required String mascota}) {
  return showModalBottomSheet<ModoConversacion>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cómo quieres responder?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              '$mascota te hará unas preguntas. Si eliges hablar, tu celular convierte tu voz '
              'en texto con el servicio de reconocimiento de Google (Android) o de Apple (iPhone), '
              'que puede procesar el audio en sus servidores. MindMetrics guarda solo tus '
              'respuestas en texto, nunca el audio.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('modo_voz'),
              onPressed: () => Navigator.pop(context, ModoConversacion.voz),
              icon: const Icon(Icons.mic),
              label: const Text('Hablar con la mascota'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('modo_texto'),
              onPressed: () => Navigator.pop(context, ModoConversacion.texto),
              icon: const Icon(Icons.keyboard),
              label: const Text('Conversar escribiendo'),
            ),
            TextButton(
              key: const ValueKey('modo_formulario'),
              onPressed: () => Navigator.pop(context, ModoConversacion.formulario),
              child: const Text('Prefiero el formulario'),
            ),
          ],
        ),
      ),
    ),
  );
}
