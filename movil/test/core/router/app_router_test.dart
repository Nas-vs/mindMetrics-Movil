// Pruebas de RF-10 (navegación principal) y de la protección de rutas.
// Se corren con:   flutter test test/core/router/
//
// El router recibe `haySesion` inyectado, así que no hace falta Supabase.

import 'package:app_bienestar/core/router/app_router.dart';
import 'package:app_bienestar/core/router/rutas.dart';
import 'package:app_bienestar/features/auth/inicio_sesion/presentation/inicio_sesion_pagina.dart';
import 'package:app_bienestar/features/onboarding/games/presentation/views/games_view.dart';
import 'package:app_bienestar/features/onboarding/home/presentation/views/home_view.dart';
import 'package:app_bienestar/features/onboarding/profile/presentation/views/profile_view.dart';
import 'package:app_bienestar/features/onboarding/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:app_bienestar/features/onboarding/survey/presentation/views/daily_survey_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Monta la app con el router real en una pantalla de celular (412×915 dp).
Future<GoRouter> montarApp(
  WidgetTester tester, {
  bool sesion = true,
  ValueNotifier<bool>? sesionCambiante,
}) async {
  tester.view.physicalSize = const Size(1236, 2745);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = crearRouter(
    haySesion: () => sesionCambiante?.value ?? sesion,
    refrescar: sesionCambiante,
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        // La fuente de pruebas de Flutter dibuja cada letra como un cuadrado
        // de 1 em (mucho más ancha que Roboto) y desborda tarjetas que en el
        // celular sí caben. Estas pruebas validan navegación, no diseño.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder get barra => find.byType(FloatingNavBar);

/// 0 = Inicio, 1 = Juegos, 2 = Perfil (orden de la barra).
Finder pestana(int indice) =>
    find.descendant(of: barra, matching: find.byType(InkWell)).at(indice);

String ubicacion(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  group('CA-1: barra visible solo en Inicio, Juegos y Perfil', () {
    testWidgets('con sesión, la app abre en /inicio con la barra', (tester) async {
      final router = await montarApp(tester);

      expect(ubicacion(router), Rutas.inicio);
      expect(find.byType(HomeView), findsOneWidget);
      expect(barra, findsOneWidget);
    });

    testWidgets('cada pestaña navega a su ruta y la barra se mantiene', (tester) async {
      final router = await montarApp(tester);

      await tester.tap(pestana(1));
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.juegos);
      expect(find.byType(GamesView), findsOneWidget);
      expect(barra, findsOneWidget);

      await tester.tap(pestana(2));
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.perfil);
      expect(find.byType(ProfileView), findsOneWidget);
      expect(barra, findsOneWidget);

      await tester.tap(pestana(0));
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.inicio);
      expect(find.byType(HomeView), findsOneWidget);
    });
  });

  group('CA-2: la barra se oculta', () {
    testWidgets('al abrir el teclado virtual', (tester) async {
      await montarApp(tester);
      expect(barra, findsOneWidget);

      // Simula el teclado ocupando la parte inferior de la pantalla.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pump();
      expect(barra, findsNothing);

      tester.view.resetViewInsets();
      await tester.pump();
      expect(barra, findsOneWidget);
    });

    testWidgets('en una pantalla de profundidad (encuesta) y vuelve al regresar', (tester) async {
      final router = await montarApp(tester);

      // Botón (+) del saludo. `context.push` apila la pantalla sin cambiar
      // la URL (go_router: optionURLReflectsImperativeAPIs = false), por eso
      // se verifica la pantalla visible y no la ubicación.
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DailySurveyView), findsOneWidget);
      expect(barra, findsNothing);

      // Flecha de regreso de la encuesta
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DailySurveyView), findsNothing);
      expect(find.byType(HomeView), findsOneWidget);
      expect(ubicacion(router), Rutas.inicio);
      expect(barra, findsOneWidget);
    });
  });

  group('Protección de rutas por sesión', () {
    testWidgets('sin sesión, abrir la app lleva a /login', (tester) async {
      final router = await montarApp(tester, sesion: false);

      expect(ubicacion(router), Rutas.login);
      expect(find.byType(InicioSesionPagina), findsOneWidget);
      expect(barra, findsNothing);
    });

    testWidgets('sin sesión, una ruta privada redirige a /login', (tester) async {
      final router = await montarApp(tester, sesion: false);

      router.go(Rutas.perfil);
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.login);
    });

    testWidgets('/verificacion sin correo vuelve a /login', (tester) async {
      final router = await montarApp(tester, sesion: false);

      router.go(Rutas.verificacion); // sin extra, como al reiniciar la app
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.login);
    });

    testWidgets('al cerrar sesión, el router envía a /login', (tester) async {
      final sesion = ValueNotifier<bool>(true);
      final router = await montarApp(tester, sesionCambiante: sesion);
      expect(ubicacion(router), Rutas.inicio);

      sesion.value = false; // equivale a supabase.auth.signOut()
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.login);
    });
  });

  group('redirigirPorSesion (regla pura)', () {
    test('sin sesión: rutas privadas → /login', () {
      expect(redirigirPorSesion(Rutas.inicio, haySesion: false), Rutas.login);
      expect(redirigirPorSesion(Rutas.encuesta, haySesion: false), Rutas.login);
    });

    test('sin sesión: rutas públicas no se redirigen', () {
      expect(redirigirPorSesion(Rutas.login, haySesion: false), isNull);
      expect(redirigirPorSesion(Rutas.registro, haySesion: false), isNull);
      expect(redirigirPorSesion(Rutas.verificacion, haySesion: false), isNull);
    });

    test('con sesión, las demás rutas no se redirigen (flujo de RF-03)', () {
      expect(redirigirPorSesion(Rutas.inicio, haySesion: true), isNull);
      expect(redirigirPorSesion(Rutas.registro, haySesion: true), isNull);
    });

    test('con sesión, /login lleva al Inicio', () {
      expect(redirigirPorSesion(Rutas.login, haySesion: true), Rutas.inicio);
    });
  });
}
