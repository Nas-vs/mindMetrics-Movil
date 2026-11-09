import 'package:flutter/material.dart';

import '../../../core/tema/app_tema.dart';
import 'conversacion_demo_pagina.dart';

/// Conversación completa escribiendo, sin Supabase ni login:
///
///   flutter run -t lib/features/avatar/demo/conversacion_demo_main.dart
void main() => runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTema.claro(),
        home: const ConversacionDemoPagina(),
      ),
    );
