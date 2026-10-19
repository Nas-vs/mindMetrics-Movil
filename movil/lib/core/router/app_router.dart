import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/registro/presentation/registro_pagina.dart';
import '../../features/onboarding/games/presentation/viewmodels/games_viewmodel.dart';
import '../../features/onboarding/games/presentation/views/games_view.dart';
import '../../features/onboarding/home/presentation/viewmodels/home_viewmodel.dart';
import '../../features/onboarding/home/presentation/views/home_view.dart';
import '../../features/onboarding/profile/presentation/viewmodels/profile_viewmodel.dart';
import '../../features/onboarding/profile/presentation/views/profile_view.dart';
import '../../features/onboarding/shell/presentation/views/main_shell_view.dart';
import '../../features/onboarding/survey/presentation/views/daily_survey_view.dart';
import '../widgets/con_view_model.dart';
import 'rutas.dart';

/// Router de la app (RF-10).
///
/// [haySesion] se inyecta para poder probar el router sin Supabase.
/// [refrescar] vuelve a evaluar el redirect cuando cambia la sesión
/// (ej. al cerrar sesión se envía al usuario a /registro).
GoRouter crearRouter({
  required bool Function() haySesion,
  Listenable? refrescar,
  String rutaInicial = Rutas.inicio,
}) {
  // Navigator raíz: las pantallas de profundidad se apilan aquí, ENCIMA del
  // shell, por eso no muestran la barra inferior (CA-2).
  final navegadorRaiz = GlobalKey<NavigatorState>(debugLabel: 'raiz');

  return GoRouter(
    navigatorKey: navegadorRaiz,
    initialLocation: rutaInicial,
    refreshListenable: refrescar,
    redirect: (_, estado) =>
        redirigirPorSesion(estado.matchedLocation, haySesion: haySesion()),
    routes: [
      GoRoute(
        path: Rutas.registro,
        // '1.0' = política vigente insertada por la migración RF-02.
        builder: (_, _) => const RegistroPagina(versionPolitica: '1.0'),
      ),
      GoRoute(
        // Placeholder hasta que exista la pantalla de RF-05.
        path: Rutas.verificacion,
        builder: (_, estado) => _VerificacionTemporal(correo: estado.extra),
      ),

      // CA-1: Inicio, Juegos y Perfil son ramas del shell → muestran la barra.
      // indexedStack conserva el estado de cada pestaña al cambiar entre ellas.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.inicio,
                builder: (_, _) => ConViewModel<HomeViewModel>(
                  crear: HomeViewModel.new,
                  builder: (_, vm) => HomeView(viewModel: vm),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.juegos,
                builder: (_, _) => ConViewModel<GamesViewModel>(
                  crear: GamesViewModel.new,
                  builder: (_, vm) => GamesView(viewModel: vm),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.perfil,
                builder: (_, _) => ConViewModel<ProfileViewModel>(
                  crear: ProfileViewModel.new,
                  builder: (_, vm) => ProfileView(viewModel: vm),
                ),
              ),
            ],
          ),
        ],
      ),

      // CA-2: pantallas de profundidad en el navigator raíz → sin barra.
      // Las siguientes (ej. detalle de juego, RF-15) se agregan igual.
      GoRoute(
        path: Rutas.encuesta,
        parentNavigatorKey: navegadorRaiz,
        builder: (_, _) => const DailySurveyView(),
      ),
    ],
  );
}

/// Regla de protección de rutas.
///
/// Sin sesión, cualquier ruta que no sea pública lleva a /registro.
/// Con sesión no se redirige nada: así, después de `signUp`, la pantalla de
/// registro puede navegar a /verificacion sin que el router la interrumpa.
String? redirigirPorSesion(String ubicacion, {required bool haySesion}) {
  if (haySesion || Rutas.publicas.contains(ubicacion)) return null;
  return Rutas.registro;
}

/// Convierte un Stream (ej. `supabase.auth.onAuthStateChange`) en un
/// Listenable para `refreshListenable` del router.
class RefrescoPorStream extends ChangeNotifier {
  RefrescoPorStream(Stream<Object?> stream) {
    _suscripcion = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _suscripcion;

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}

/// Placeholder de RF-05 (se movió desde main.dart sin cambios de diseño).
class _VerificacionTemporal extends StatelessWidget {
  const _VerificacionTemporal({required this.correo});

  final Object? correo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 72, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Cuenta creada para\n${correo ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(Rutas.inicio),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
