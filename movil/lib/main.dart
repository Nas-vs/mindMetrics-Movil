import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/registro/presentation/registro_pagina.dart';
import 'features/onboarding/shell/presentation/views/main_shell_view.dart';
import 'features/onboarding/core/constants/app_colors.dart';

/// Supabase local (`supabase start`). El emulador de Android ve el host en
/// 10.0.2.2; el simulador de iOS usa 127.0.0.1.
/// Se pueden sobrescribir con --dart-define=SUPABASE_URL=... / SUPABASE_ANON_KEY=...
const _urlDefinida = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  // Anon key pública por defecto del Supabase CLI local (no es un secreto).
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
);

String get _supabaseUrl {
  if (_urlDefinida.isNotEmpty) return _urlDefinida;
  return Platform.isAndroid
      ? 'http://10.0.2.2:54321'
      : 'http://127.0.0.1:54321';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _anonKey);
  runApp(const ProviderScope(child: MyApp()));
}

final _router = GoRouter(
  initialLocation: '/registro',
  routes: [
    GoRoute(
      path: '/registro',
      // '1.0' = política vigente insertada por la migración RF-02.
      builder: (_, _) => const RegistroPagina(versionPolitica: '1.0'),
    ),
    GoRoute(
      // Placeholder hasta que exista la pantalla de RF-05.
      path: '/verificacion',
      builder: (context, state) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 72, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'Cuenta creada para\n${state.extra ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Ir al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    GoRoute(path: '/home', builder: (_, _) => const MainShell()),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MindMetrics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
      ),
      routerConfig: _router,
    );
  }
}
