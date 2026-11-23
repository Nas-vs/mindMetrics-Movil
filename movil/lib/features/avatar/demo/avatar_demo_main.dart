import 'package:flutter/material.dart';

import '../../../core/tema/app_tema.dart';
import 'avatar_demo_pagina.dart';

/// Punto de entrada solo para probar el avatar sin Supabase ni login:
///
///   flutter run -t lib/features/avatar/demo/avatar_demo_main.dart
void main() => runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTema.claro(),
        home: const AvatarDemoPagina(),
      ),
    );
