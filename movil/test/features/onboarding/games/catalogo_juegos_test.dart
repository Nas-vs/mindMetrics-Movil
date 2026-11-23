import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_bienestar/features/onboarding/games/data/juegos_repositorio.dart';
import 'package:app_bienestar/features/onboarding/games/domain/juego.dart';
import 'package:app_bienestar/features/onboarding/games/presentation/viewmodels/games_viewmodel.dart';
import 'package:app_bienestar/features/onboarding/games/presentation/views/games_view.dart';

/// Repositorio de prueba en memoria (no toca Supabase ni internet).
class MockJuegosRepositorio extends JuegosRepositorio {
  MockJuegosRepositorio({this.nivelMock});
  final int? nivelMock;

  @override
  Future<int?> obtenerUltimoNivelAnimo() async => nivelMock;
}

void main() {
  group('RF-14: Catálogo de juegos (Pruebas unitarias y de ViewModel)', () {
    test('CA-1 y CA-4: El catálogo base contiene los juegos requeridos con datos válidos', () async {
      final repo = MockJuegosRepositorio();
      final juegos = await repo.obtenerJuegos();

      expect(juegos.length, 5);
      for (final juego in juegos) {
        expect(juego.id.isNotEmpty, true);
        expect(juego.nombre.isNotEmpty, true);
        expect(juego.duracionAproximada.isNotEmpty, true);
        expect(juego.descripcionCorta.isNotEmpty, true);
      }
    });

    test(
      'CA-2: Filtrar por objetivo terapéutico reduce la lista correctamente',
      () async {
        final repo = MockJuegosRepositorio();
        final vm = GamesViewModel(repositorio: repo);
        await pumpEventQueue();

        expect(vm.juegosFiltrados.length, 5);

        // Filtrar por 'Relajarme' (debe dejar 2 juegos)
        vm.seleccionarFiltro(ObjetivoJuego.relajarme);
        expect(vm.filtroSeleccionado, ObjetivoJuego.relajarme);
        expect(vm.juegosFiltrados.length, 2);
        expect(
          vm.juegosFiltrados.every(
            (j) => j.objetivo == ObjetivoJuego.relajarme,
          ),
          true,
        );

        // Desactivar filtro (volver a Todos)
        vm.seleccionarFiltro(ObjetivoJuego.relajarme);
        expect(vm.filtroSeleccionado, isNull);
        expect(vm.juegosFiltrados.length, 5);
      },
    );

    test('CA-3: Nivel de ánimo bajo (1 o 2) recomienda Respiración y lo ubica de primero', () async {
      final repo = MockJuegosRepositorio(nivelMock: 2);
      final juegos = await repo.obtenerJuegos();

      expect(juegos.first.id, 'respiracion_sostenida');
      expect(juegos.first.recomendado, true);
    });

    test(
      'CA-3: Nivel de ánimo positivo (4 o 5) recomienda Jardín emocional',
      () async {
        final repo = MockJuegosRepositorio(nivelMock: 5);
        final juegos = await repo.obtenerJuegos();

        expect(juegos.first.id, 'jardin_emocional');
        expect(juegos.first.recomendado, true);
      },
    );

    test(
      'CA-3: Nivel de ánimo neutro (3) recomienda Memoria de emociones',
      () async {
        final repo = MockJuegosRepositorio(nivelMock: 3);
        final juegos = await repo.obtenerJuegos();

        expect(juegos.first.id, 'memoria_emociones');
        expect(juegos.first.recomendado, true);
      },
    );
  });

  group('RF-14: Pruebas de interfaz visual (Widget Tests)', () {
    testWidgets(
      'CA-1, CA-2 y CA-3: Renderiza la pantalla y filtra al tocar los chips',
      (tester) async {
        final repo = MockJuegosRepositorio(nivelMock: 4);
        final vm = GamesViewModel(repositorio: repo);
        await pumpEventQueue();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GamesView(viewModel: vm)),
          ),
        );
        await tester.pumpAndSettle();

        // Comprueba títulos y chips principales
        expect(find.text('Juegos de bienestar'), findsOneWidget);
        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Relajarme'), findsOneWidget);
        expect(find.text('Constancia'), findsOneWidget);

        // Comprueba el badge de recomendado (CA-3)
        expect(find.text('Recomendado'), findsOneWidget);

        // Inicialmente se ven todos los juegos
        expect(find.text('Jardín emocional'), findsOneWidget);
        expect(find.text('Respiración sostenida'), findsOneWidget);

        // Simula el toque en el chip "Constancia" (CA-2)
        await tester.tap(find.text('Constancia'));
        await tester.pumpAndSettle();

        // Ahora solo debe mostrarse Jardín emocional y no Respiración
        expect(find.text('Jardín emocional'), findsOneWidget);
        expect(find.text('Respiración sostenida'), findsNothing);
      },
    );
  });
}
