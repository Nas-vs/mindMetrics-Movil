import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/estado_avatar.dart';
import '../domain/personaje_avatar.dart';
import '../presentation/avatar_controlador.dart';
import '../presentation/avatar_mascota.dart';

/// Banco de pruebas del avatar (solo desarrollo).
///
/// Permite cambiar personaje, actividad y emoción, simular un turno
/// completo y probar la boca con un nivel de voz manual (como lo enviaría
/// un TTS que sí entregue amplitud).
class AvatarDemoPagina extends StatefulWidget {
  const AvatarDemoPagina({super.key});

  @override
  State<AvatarDemoPagina> createState() => _AvatarDemoPaginaState();
}

class _AvatarDemoPaginaState extends State<AvatarDemoPagina> {
  final _controlador = AvatarControlador();
  PersonajeAvatar _personaje = PersonajesAvatar.nimbus;
  bool _nivelManual = false;
  double _nivel = 0.5;
  bool _simulando = false;

  @override
  void dispose() {
    _simulando = false;
    _controlador.dispose();
    super.dispose();
  }

  /// Un turno de ejemplo: saluda, pregunta, escucha, procesa y responde.
  Future<void> _simularTurno() async {
    setState(() => _simulando = true);
    final pasos = <(void Function(), int)>[
      (() => _controlador.hablar(emocion: EmocionAvatar.alegre), 2200),
      (() => _controlador.hablar(emocion: EmocionAvatar.empatico), 2600),
      (_controlador.escuchar, 3000),
      (_controlador.pensar, 1800),
      (() => _controlador.hablar(emocion: EmocionAvatar.neutral), 2400),
      (_controlador.detener, 0),
    ];
    for (final (accion, ms) in pasos) {
      if (!mounted || !_simulando) return;
      accion();
      await Future<void>.delayed(Duration(milliseconds: ms));
    }
    if (mounted) setState(() => _simulando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avatar · banco de pruebas')),
      body: ListenableBuilder(
        listenable: _controlador,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: AvatarMascota(
                  key: ValueKey(_personaje.id),
                  personaje: _personaje,
                  controlador: _controlador,
                  tamano: 240,
                ),
              ),
            ),
            Center(
              child: Text(
                '${_controlador.estado.actividad.name} · '
                '${_controlador.estado.emocion.name}',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PersonajeAvatar>(
              segments: [
                for (final p in PersonajesAvatar.todos)
                  ButtonSegment(value: p, label: Text(p.nombre)),
              ],
              selected: {_personaje},
              onSelectionChanged: (s) => setState(() => _personaje = s.first),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _controlador.detener,
                  child: const Text('Reposo'),
                ),
                FilledButton.tonal(
                  onPressed: _controlador.escuchar,
                  child: const Text('Escuchar'),
                ),
                FilledButton.tonal(
                  onPressed: _controlador.pensar,
                  child: const Text('Pensar'),
                ),
                FilledButton.tonal(
                  onPressed: () => _controlador.hablar(),
                  child: const Text('Hablar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<EmocionAvatar>(
              segments: const [
                ButtonSegment(value: EmocionAvatar.neutral, label: Text('Neutral')),
                ButtonSegment(value: EmocionAvatar.alegre, label: Text('Alegre')),
                ButtonSegment(value: EmocionAvatar.empatico, label: Text('Empático')),
              ],
              selected: {_controlador.estado.emocion},
              onSelectionChanged: (s) => _controlador.cambiarEmocion(s.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Nivel de voz manual'),
              subtitle: const Text('Simula un TTS que entrega la amplitud'),
              value: _nivelManual,
              onChanged: (v) => setState(() => _nivelManual = v),
            ),
            if (_nivelManual)
              Slider(
                value: _nivel,
                onChanged: (v) {
                  setState(() => _nivel = v);
                  _controlador.actualizarNivelVoz(v);
                },
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _simulando ? null : _simularTurno,
              child: Text(_simulando ? 'Simulando…' : 'Simular un turno'),
            ),
          ],
        ),
      ),
    );
  }
}
