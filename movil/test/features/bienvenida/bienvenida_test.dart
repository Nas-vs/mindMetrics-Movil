// Pruebas de RF-01 (bienvenida). Se corren con:
//   flutter test test/features/bienvenida/

import 'package:app_bienestar/core/router/app_router.dart';
import 'package:app_bienestar/core/router/rutas.dart';
import 'package:app_bienestar/features/bienvenida/data/estado_bienvenida.dart';
import 'package:app_bienestar/features/bienvenida/presentation/bienvenida_pagina.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> montarPagina(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1236, 2745);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      // La fuente de pruebas es más ancha que la real: solo se valida lógica.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(0.5)),
        child: child!,
      ),
      home: BienvenidaPagina(onTerminar: () {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('EstadoBienvenida (CA-4)', () {
    test('la primera vez está pendiente', () async {
      SharedPreferences.setMockInitialValues({});
      final estado = await EstadoBienvenida.cargar();
      expect(estado.pendiente, isTrue);
    });

    test('al completarla se guarda y no vuelve a salir', () async {
      SharedPreferences.setMockInitialValues({});
      final estado = await EstadoBienvenida.cargar();
      await estado.completar();
      expect(estado.pendiente, isFalse);

      // Como si la app se abriera de nuevo
      final otraVez = await EstadoBienvenida.cargar();
      expect(otraVez.pendiente, isFalse);
      final preferencias = await SharedPreferences.getInstance();
      expect(preferencias.getBool(EstadoBienvenida.clave), isTrue);
    });
  });

  group('redirigirPorSesion · RF-01', () {
    test('primera vez y sin sesión → /bienvenida', () {
      expect(
        redirigirPorSesion(Rutas.login, haySesion: false, bienvenidaPendiente: true),
        Rutas.bienvenida,
      );
      expect(
        redirigirPorSesion(Rutas.bienvenida,
            haySesion: false, bienvenidaPendiente: true),
        isNull,
      );
    });

    test('ya vista → /bienvenida es pública y no se fuerza', () {
      expect(redirigirPorSesion(Rutas.login, haySesion: false), isNull);
      expect(redirigirPorSesion(Rutas.bienvenida, haySesion: false), isNull);
    });

    test('con sesión no se muestra la bienvenida', () {
      expect(
        redirigirPorSesion(Rutas.inicio, haySesion: true, bienvenidaPendiente: true),
        isNull,
      );
    });
  });

  group('BienvenidaPagina', () {
    testWidgets('muestra las 3 pantallas con sus textos (CA-1)', (tester) async {
      await montarPagina(tester);
      expect(find.text('Registra cómo te sientes cada día'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Descubre patrones en tu bienestar'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Esta app no reemplaza la atención profesional'), findsOneWidget);
    });

    testWidgets('"Saltar" en las pantallas 1 y 2, no en la 3 (CA-2)', (tester) async {
      await montarPagina(tester);
      expect(find.text('Saltar'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Saltar'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Saltar'), findsNothing);
      expect(find.text('Comenzar'), findsOneWidget);
    });

    testWidgets('se puede avanzar deslizando (CA-2)', (tester) async {
      await montarPagina(tester);
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Descubre patrones en tu bienestar'), findsOneWidget);
    });

    testWidgets('"Comenzar" termina la bienvenida (CA-3)', (tester) async {
      var terminados = 0;
      tester.view.physicalSize = const Size(1236, 2745);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
        home: BienvenidaPagina(onTerminar: () => terminados++),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comenzar'));
      expect(terminados, 1);
    });

    testWidgets('"Saltar" también termina la bienvenida (CA-2)', (tester) async {
      var terminados = 0;
      tester.view.physicalSize = const Size(1236, 2745);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
        home: BienvenidaPagina(onTerminar: () => terminados++),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saltar'));
      expect(terminados, 1);
    });
  });
}
