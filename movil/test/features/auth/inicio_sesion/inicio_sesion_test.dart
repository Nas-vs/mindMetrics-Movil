// Pruebas del RF-04 sin Supabase ni celular.
// Se corren con:   flutter test test/features/auth/inicio_sesion/

import 'package:app_bienestar/features/auth/inicio_sesion/data/inicio_sesion_repositorio.dart';
import 'package:app_bienestar/features/auth/inicio_sesion/presentation/inicio_sesion_vista_modelo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositorioFalso implements InicioSesionRepositorio {
  RepositorioFalso({this.resultado, this.error});

  final ResultadoInicioSesion? resultado;
  final ErrorInicioSesion? error;
  int llamadas = 0;

  @override
  Future<ResultadoInicioSesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    llamadas++;
    final e = error;
    if (e != null) throw InicioSesionExcepcion(e);
    return resultado!;
  }
}

ProviderContainer crearContenedor(RepositorioFalso repo) {
  final container = ProviderContainer(
    overrides: [inicioSesionRepositorioProvider.overrideWithValue(repo)],
  );
  container.listen(inicioSesionVistaModeloProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('celular conocido → sesión iniciada (CA-4)', () async {
    final c = crearContenedor(
      RepositorioFalso(resultado: ResultadoInicioSesion.sesionIniciada),
    );
    await c.read(inicioSesionVistaModeloProvider.notifier)
        .iniciarSesion(correo: 'ana@prueba.co', contrasena: 'Prueba123');

    expect(c.read(inicioSesionVistaModeloProvider).resultado,
        ResultadoInicioSesion.sesionIniciada);
  });

  test('celular nuevo → pide código (CA-5)', () async {
    final c = crearContenedor(
      RepositorioFalso(resultado: ResultadoInicioSesion.requiereCodigo),
    );
    await c.read(inicioSesionVistaModeloProvider.notifier)
        .iniciarSesion(correo: 'ana@prueba.co', contrasena: 'Prueba123');

    expect(c.read(inicioSesionVistaModeloProvider).resultado,
        ResultadoInicioSesion.requiereCodigo);
  });

  test('credenciales inválidas llegan como error de dominio (CA-6)', () async {
    final c = crearContenedor(
      RepositorioFalso(error: ErrorInicioSesion.credencialesInvalidas),
    );
    await c.read(inicioSesionVistaModeloProvider.notifier)
        .iniciarSesion(correo: 'ana@prueba.co', contrasena: 'mala');

    final estado = c.read(inicioSesionVistaModeloProvider);
    expect(estado.error, ErrorInicioSesion.credencialesInvalidas);
    expect(estado.cargando, isFalse);
  });

  test('bloqueo de 15 minutos (CA-7)', () async {
    final c = crearContenedor(RepositorioFalso(error: ErrorInicioSesion.bloqueado));
    await c.read(inicioSesionVistaModeloProvider.notifier)
        .iniciarSesion(correo: 'ana@prueba.co', contrasena: 'mala');

    expect(c.read(inicioSesionVistaModeloProvider).error, ErrorInicioSesion.bloqueado);
  });

  test('no envía dos veces mientras carga (CA-3)', () async {
    final repo = RepositorioFalso(resultado: ResultadoInicioSesion.requiereCodigo);
    final c = crearContenedor(repo);
    final vm = c.read(inicioSesionVistaModeloProvider.notifier);

    await Future.wait([
      vm.iniciarSesion(correo: 'ana@prueba.co', contrasena: 'Prueba123'),
      vm.iniciarSesion(correo: 'ana@prueba.co', contrasena: 'Prueba123'),
    ]);
    expect(repo.llamadas, 1);
  });
}
