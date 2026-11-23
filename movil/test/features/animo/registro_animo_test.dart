import 'package:app_bienestar/features/animo/data/registro_animo_repositorio.dart';
import 'package:app_bienestar/features/animo/domain/registro_animo.dart';
import 'package:app_bienestar/features/animo/presentation/registro_animo_vista_modelo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_animo.dart';

void main() {
  final ahora = DateTime(2026, 11, 21, 22, 30);
  RegistroAnimoVistaModelo vmCon(RepositorioAnimoFalso repo) =>
      RegistroAnimoVistaModelo(repo, reloj: () => ahora);

  group('RF-08 registro rápido de ánimo', () {
    test('CA-2: sin elegir emoji no se puede guardar', () async {
      final vm = vmCon(RepositorioAnimoFalso());
      await vm.cargar();
      expect(vm.puedeGuardar, isFalse);
      expect(await vm.guardar(), isNull);
      vm.elegirNivel(4);
      expect(vm.puedeGuardar, isTrue);
    });

    test('guarda con el día LOCAL y solo el nivel (detalle opcional, CA-4)', () async {
      final repo = RepositorioAnimoFalso();
      final vm = vmCon(repo);
      await vm.cargar();
      vm.elegirNivel(3);
      expect(await vm.guardar(), ResultadoGuardado.sincronizado);
      final r = repo.guardados.single;
      expect(r.fecha, '2026-11-21');
      expect(r.nivel, 3);
      expect(r.emociones, isEmpty);
      expect(r.nota, isNull);
    });

    test('CA-4: emociones, factores y nota se envían; la nota se recorta', () async {
      final repo = RepositorioAnimoFalso();
      final vm = vmCon(repo);
      await vm.cargar();
      vm
        ..elegirNivel(5)
        ..alternarEmocion(1)
        ..alternarEmocion(2)
        ..alternarEmocion(2) // deseleccionar
        ..alternarFactor(1)
        ..cambiarNota('  buen día  ');
      await vm.guardar();
      final r = repo.guardados.single;
      expect(r.emociones, {1});
      expect(r.factores, {1});
      expect(r.nota, 'buen día');
    });

    test('CA-3: si ya registró hoy, carga en modo edición con el mismo id', () async {
      final repo = RepositorioAnimoFalso(
        existente: RegistroAnimo(
          id: 'id-existente',
          fecha: '2026-11-21',
          nivel: 2,
          emociones: const {1},
          nota: 'cansado',
          actualizadoEnCliente: DateTime(2026, 11, 21, 8),
        ),
      );
      final vm = vmCon(repo);
      await vm.cargar();
      expect(vm.esEdicion, isTrue);
      expect(vm.nivel, 2);
      expect(vm.panelAbierto, isTrue);
      vm.elegirNivel(4);
      await vm.guardar();
      expect(repo.guardados.single.id, 'id-existente');
    });

    test('dos guardados seguidos reutilizan el id (un registro por día)', () async {
      final repo = RepositorioAnimoFalso();
      final vm = vmCon(repo);
      await vm.cargar();
      vm.elegirNivel(1);
      await vm.guardar();
      vm.elegirNivel(2);
      await vm.guardar();
      expect(repo.guardados.map((r) => r.id).toSet(), hasLength(1));
    });

    test('sin conexión devuelve pendiente (se sincroniza después)', () async {
      final vm = vmCon(RepositorioAnimoFalso(resultado: ResultadoGuardado.pendienteSinConexion));
      await vm.cargar();
      vm.elegirNivel(3);
      expect(await vm.guardar(), ResultadoGuardado.pendienteSinConexion);
    });

    test('error del servidor muestra un mensaje en español', () async {
      final vm = vmCon(RepositorioAnimoFalso(errorServidor: 'nota_muy_larga'));
      await vm.cargar();
      vm.elegirNivel(3);
      expect(await vm.guardar(), isNull);
      expect(vm.aviso, contains('500'));
      expect(vm.guardando, isFalse);
    });

    test('CA-8: expone la alerta pendiente y la marca como vista', () async {
      final repo = RepositorioAnimoFalso(
        alerta: const AlertaBienestar(id: 'a1', motivo: 'racha_baja'),
      );
      final vm = vmCon(repo);
      expect((await vm.alertaPendiente())?.motivo, 'racha_baja');
      await vm.marcarAlertaVista('a1');
      expect(repo.alertasVistas, ['a1']);
    });
  });

  group('RegistroAnimo JSON', () {
    test('lee la fila con tablas anidadas y la respuesta de la RPC', () {
      final fila = RegistroAnimo.desdeJson({
        'id': 'x',
        'fecha': '2026-11-21',
        'nivel': 4,
        'nota': null,
        'actualizado_en_cliente': '2026-11-21T10:00:00Z',
        'registro_emociones': [{'emocion_id': 3}],
        'registro_factores': [{'factor_id': 2}],
      });
      expect(fila.emociones, {3});
      expect(fila.factores, {2});
      final ida = RegistroAnimo.desdeJson(fila.aJson());
      expect(ida.emociones, {3});
      expect(ida.nivel, 4);
    });
  });
}
