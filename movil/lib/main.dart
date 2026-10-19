import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'features/onboarding/core/constants/app_colors.dart';

/// Supabase local (`supabase start`). El emulador de Android ve el host en
/// 10.0.2.2; el simulador de iOS y la web usan 127.0.0.1.
/// Se pueden sobrescribir con --dart-define=SUPABASE_URL=... / SUPABASE_ANON_KEY=...
const _urlDefinida = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  // Anon key pública por defecto del Supabase CLI local (no es un secreto).
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
);

String get _supabaseUrl {
  if (_urlDefinida.isNotEmpty) return _urlDefinida;
  // En web no existe dart:io Platform (lanzaría UnsupportedError).
  if (kIsWeb) return 'http://127.0.0.1:54321';
  return Platform.isAndroid
      ? 'http://10.0.2.2:54321'
      : 'http://127.0.0.1:54321';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _anonKey);

  final auth = Supabase.instance.client.auth;
  final router = crearRouter(
    haySesion: () => auth.currentSession != null,
    refrescar: RefrescoPorStream(auth.onAuthStateChange),
  );

  runApp(ProviderScope(child: MyApp(router: router)));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.router});

  final GoRouter router;

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
      routerConfig: router,
    );
  }
}
