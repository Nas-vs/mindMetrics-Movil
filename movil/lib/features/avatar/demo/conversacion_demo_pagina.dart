import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/personaje_avatar.dart';
import '../presentation/conversacion_pagina.dart';

/// Banco de pruebas de la conversación (solo desarrollo).
///
/// Usa la página real, con voz si el dispositivo la tiene, pero NO guarda
/// en Supabase: al terminar muestra la fila que se guardaría en
/// `evaluaciones_iniciales`. No necesita login.
class ConversacionDemoPagina extends StatefulWidget {
  const ConversacionDemoPagina({super.key});

  @override
  State<ConversacionDemoPagina> createState() => _ConversacionDemoPaginaState();
}

class _ConversacionDemoPaginaState extends State<ConversacionDemoPagina> {
  PersonajeAvatar _personaje = PersonajesAvatar.nimbus;
  Map<String, Object>? _fila;
  String? _resultado;

  Future<void> _abrir() async {
    setState(() => _fila = null);
    final r = await Navigator.of(context).push<ResultadoConversacion>(MaterialPageRoute(
      builder: (_) => ConversacionPagina(
        personaje: _personaje,
        guardar: (fila) async => setState(() => _fila = fila),
      ),
    ));
    if (mounted) setState(() => _resultado = r?.name ?? 'cancelada');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversación · banco de pruebas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<PersonajeAvatar>(
            segments: [
              for (final p in PersonajesAvatar.todos) ButtonSegment(value: p, label: Text(p.nombre)),
            ],
            selected: {_personaje},
            onSelectionChanged: (s) => setState(() => _personaje = s.first),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _abrir, child: const Text('Empezar conversación')),
          if (_resultado != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('Resultado: $_resultado'),
          ),
          if (_fila != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  'Fila para evaluaciones_iniciales:\n'
                  '${const JsonEncoder.withIndent('  ').convert(_fila)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
