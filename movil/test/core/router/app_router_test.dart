// Pruebas de RF-10 (navegación principal) y de la protección de rutas.
// Se corren con:   flutter test test/core/router/
//
// El router recibe `haySesion` inyectado, así que no hace falta Supabase.

import 'dart:async';

import 'package:app_bienestar/core/router/app_router.dart';
import 'package:app_bienestar/core/router/estado_recuperacion.dart';
import 'package:app_bienestar/core/router/rutas.dart';
import 'package:app_bienestar/features/auth/inicio_sesion/presentation/inicio_sesion_pagina.dart';
import 'package:app_bienestar/features/auth/recuperar_contrasena/presentation/recuperar_contrasena_pagina.dart';
import 'package:app_bienestar/features/auth/recuperar_contrasena/presentation/restablecer_contrasena_pagina.dart';
import 'package:app_bienestar/features/onboarding/games/presentation/views/games_view.dart';
import 'package:app_bienestar/features/onboarding/home/presentation/views/home_view.dart';
import 'package:app_bienestar/features/onboarding/profile/presentation/views/profile_view.dart';
import 'package:app_bienestar/features/onboarding/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:app_bienestar/features/onboarding/survey/presentation/views/daily_survey_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthException, AuthState;

/// Monta la app con el router real en una pantalla de celular (412×915 dp).
Future<GoRouter> montarApp(
  WidgetTester tester, {
  bool sesion = true,
  ValueNotifier<bool>? sesionCambiante,
  EstadoRecuperacion? recuperacion,
}) async {
  tester.view.physicalSize = const Size(1236, 2745);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = crearRouter(
    haySesion: () => sesionCambiante?.value ?? sesion,
    refrescar: sesionCambiante,
    recuperacion: recuperacion,
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

  group('RF-06 recuperar contraseña', () {
    testWidgets('"¿Olvidó su contraseña?" abre /recuperar-contrasena',
        (tester) async {
      final router = await montarApp(tester, sesion: false);

      await tester.tap(find.text('¿Olvidó su contraseña?'));
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.recuperarContrasena);
      expect(find.byType(RecuperarContrasenaPagina), findsOneWidget);
    });

    testWidgets('el enlace del correo lleva a /restablecer-contrasena',
        (tester) async {
      final eventos = StreamController<AuthState>();
      addTearDown(eventos.close);
      final sesion = ValueNotifier<bool>(false);
      final recuperacion = EstadoRecuperacion(eventos.stream);
      final router = await montarApp(
        tester,
        sesionCambiante: sesion,
        recuperacion: recuperacion,
      );
      expect(ubicacion(router), Rutas.login);

      // Lo que hace supabase_flutter al abrir mindmetrics://...?code=...
      sesion.value = true;
      eventos.add(const AuthState(AuthChangeEvent.passwordRecovery, null));
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.restablecerContrasena);
      expect(find.byType(RestablecerContrasenaPagina), findsOneWidget);

      // Con la sesión temporal no se puede ir a otra parte.
      router.go(Rutas.inicio);
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.restablecerContrasena);

      // Al cambiar la contraseña (o cancelar) se cierra la sesión → login.
      sesion.value = false;
      eventos.add(const AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.login);
    });

    testWidgets('enlace vencido muestra el aviso en /recuperar-contrasena (CA-7)',
        (tester) async {
      final eventos = StreamController<AuthState>();
      addTearDown(eventos.close);
      final recuperacion = EstadoRecuperacion(eventos.stream);
      final router = await montarApp(
        tester,
        sesion: false,
        recuperacion: recuperacion,
      );

      eventos.addError(
        const AuthException('Email link is invalid or has expired',
            statusCode: 'otp_expired', code: 'access_denied'),
      );
      await tester.pumpAndSettle();
      expect(ubicacion(router), Rutas.recuperarContrasena);
      expect(find.textContaining('Este enlace ya no es válido'), findsOneWidget);
      expect(find.text('Solicitar uno nuevo'), findsOneWidget);
      // La pantalla ya mostró el aviso: el router no vuelve a forzarlo.
      expect(recuperacion.enlaceInvalido, isFalse);
    });
  });

  group('redirigirPorSesion · RF-06', () {
    test('/recuperar-contrasena es pública', () {
      expect(redirigirPorSesion(Rutas.recuperarContrasena, haySesion: false), isNull);
    });

    test('/restablecer-contrasena sin sesión → /login', () {
      expect(redirigirPorSesion(Rutas.restablecerContrasena, haySesion: false),
          Rutas.login);
    });

    test('recuperando, todo lleva a /restablecer-contrasena', () {
      for (final ruta in [Rutas.login, Rutas.inicio, Rutas.perfil]) {
        expect(
          redirigirPorSesion(ruta, haySesion: true, recuperando: true),
          Rutas.restablecerContrasena,
        );
      }
      expect(
        redirigirPorSesion(Rutas.restablecerContrasena,
            haySesion: true, recuperando: true),
        isNull,
      );
    });

    test('enlace inválido sin sesión → /recuperar-contrasena', () {
      expect(
        redirigirPorSesion(Rutas.login, haySesion: false, enlaceInvalido: true),
        Rutas.recuperarContrasena,
      );
    });
  });

  group('EstadoRecuperacion.esErrorDeEnlace', () {
    test('reconoce los errores del enlace del correo', () {
      expect(
        EstadoRecuperacion.esErrorDeEnlace(
          const AuthException('x', statusCode: 'otp_expired', code: 'access_denied'),
        ),
        isTrue,
      );
    });

    test('ignora otros errores de Auth (p. ej. refresh token)', () {
      expect(
        EstadoRecuperacion.esErrorDeEnlace(
          const AuthException('x', code: 'refresh_token_not_found'),
        ),
        isFalse,
      );
      expect(EstadoRecuperacion.esErrorDeEnlace(Exception('x')), isFalse);
    });
  });
}
