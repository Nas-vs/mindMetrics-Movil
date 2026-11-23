import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_bienestar/features/onboarding/home/data/models/home_summary_model.dart';
import 'package:app_bienestar/features/onboarding/home/data/repositories/home_repository.dart';
import 'package:app_bienestar/features/onboarding/home/presentation/viewmodels/home_viewmodel.dart';

class _RepoFalso implements HomeRepository {
  _RepoFalso(this.resumen);
  HomeSummaryModel resumen;
  int llamadas = 0;

  @override
  Future<HomeSummaryModel> getHomeSummary() async {
    llamadas++;
    return resumen;
  }
}

void main() {
  // El ViewModel registra un AppLifecycleListener, que necesita el binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Domingo 22 de noviembre de 2026
  final hoy = DateTime(2026, 11, 22, 20, 30);

  group('Racha de registros', () {
    test('cuenta los días seguidos hasta hoy', () {
      final n = {'2026-11-22': 4, '2026-11-21': 3, '2026-11-20': 5, '2026-11-18': 2};
      expect(HomeSummaryModel.calcularRacha(n, hoy), 3);
    });

    test('si hoy aún no registra, la racha sigue viva desde ayer', () {
      final n = {'2026-11-21': 3, '2026-11-20': 5};
      expect(HomeSummaryModel.calcularRacha(n, hoy), 2);
    });

    test('se rompe si faltó ayer y hoy', () {
      expect(HomeSummaryModel.calcularRacha({'2026-11-19': 3}, hoy), 0);
    });

    test('cruza el cambio de mes', () {
      final n = {'2026-12-01': 3, '2026-11-30': 4};
      expect(HomeSummaryModel.calcularRacha(n, DateTime(2026, 12, 1)), 2);
    });
  });

  group('Última semana registrada', () {
    test('es la semana lunes–domingo del registro más reciente', () {
      final n = {'2026-11-11': 2, '2026-11-13': 5}; // miércoles y viernes
      final semana = HomeSummaryModel.ultimaSemanaRegistrada(n, hoy);
      expect(semana, hasLength(7));
      expect(semana.first.fecha, DateTime(2026, 11, 9)); // lunes
      expect(semana.last.fecha, DateTime(2026, 11, 15)); // domingo
      expect(semana[2].nivel, 2);
      expect(semana[4].nivel, 5);
      expect(semana[0].nivel, isNull);
      expect(HomeSummaryModel.tituloSemana(semana, hoy), 'Semana del 9 al 15 nov');
    });

    test('si el último registro es de esta semana, se titula "Esta semana"', () {
      final semana = HomeSummaryModel.ultimaSemanaRegistrada({'2026-11-17': 3}, hoy);
      expect(semana.first.fecha, DateTime(2026, 11, 16));
      expect(HomeSummaryModel.tituloSemana(semana, hoy), 'Esta semana');
    });

    test('semana que cruza dos meses', () {
      final semana = HomeSummaryModel.ultimaSemanaRegistrada({'2026-12-02': 4}, hoy);
      expect(semana.first.fecha, DateTime(2026, 11, 30));
      expect(HomeSummaryModel.tituloSemana(semana, hoy), 'Semana del 30 nov al 6 dic');
    });

    test('sin registros devuelve la semana actual vacía', () {
      final semana = HomeSummaryModel.ultimaSemanaRegistrada({}, hoy);
      expect(semana.first.fecha, DateTime(2026, 11, 16));
      expect(semana.every((d) => d.nivel == null), isTrue);
    });
  });

  group('Resultado de la evaluación', () {
    test('texto corto según el estado', () {
      expect(const ResultadoEvaluacion.pendiente().textoCorto, 'Pendiente');
      expect(const ResultadoEvaluacion.calculando().textoCorto, 'En cálculo…');
      final listo = ResultadoEvaluacion.desdeJson({
        'nivel': 2,
        'origen': 'evaluacion_inicial',
        'calculado_en': '2026-11-20T15:00:00Z',
      });
      expect(listo.textoCorto, 'Riesgo bajo');
      expect(listo.etiqueta, 'Bajo');
    });
  });

  group('HomeViewModel', () {
    test('muestra el ánimo de hoy, el nivel y la racha', () async {
      final repo = _RepoFalso(HomeSummaryModel(
        username: 'juli',
        animoHoy: 4,
        racha: 1,
        evaluacion: ResultadoEvaluacion.desdeJson({'nivel': 3, 'origen': 'evaluacion_inicial'}),
      ));
      final aviso = ValueNotifier<int>(0);
      final vm = HomeViewModel(repository: repo, ahora: () => hoy, recargarCuando: aviso);
      await Future<void>.delayed(Duration.zero);

      expect(vm.username, 'juli');
      expect(vm.estadoHoy, '🙂 Bien');
      expect(vm.resultadoEvaluacion, 'Riesgo moderado');
      expect(vm.racha, '1 DÍA');

      // RF-08 guardó el ánimo → el Inicio vuelve a consultar
      aviso.value++;
      await Future<void>.delayed(Duration.zero);
      expect(repo.llamadas, 2);

      vm.dispose();
      aviso.value++;
      expect(repo.llamadas, 2); // ya no escucha
    });

    test('sin registro hoy muestra "Sin registrar"', () async {
      final vm = HomeViewModel(
        repository: _RepoFalso(const HomeSummaryModel(username: 'x')),
        ahora: () => hoy,
        recargarCuando: ValueNotifier<int>(0),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.estadoHoy, 'Sin registrar');
      expect(vm.racha, '0 DÍAS');
      vm.dispose();
    });
  });
}
