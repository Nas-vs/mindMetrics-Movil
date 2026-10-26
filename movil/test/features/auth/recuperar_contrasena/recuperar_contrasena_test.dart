// Pruebas del RF-06 sin Supabase ni celular.
// Se corren con:   flutter test test/features/auth/recuperar_contrasena/

import 'package:app_bienestar/features/auth/recuperar_contrasena/data/recuperar_contrasena_repositorio.dart';
import 'package:app_bienestar/features/auth/recuperar_contrasena/presentation/recuperar_contrasena_vista_modelo.dart';
import 'package:app_bienestar/features/auth/recuperar_contrasena/presentation/restablecer_contrasena_vista_modelo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositorioFalso implements RecuperarContrasenaRepositorio {
  ErrorRecuperacion? error;
  final correos = <String>[];
  final contrasenas = <String>[];
  int cancelaciones = 0;

  @override
  Future<void> solicitarEnlace(String correo) async {
    correos.add(correo);
    final e = error;
    if (e != null) throw RecuperacionExcepcion(e);
  }

  @override
  Future<void> restablecer(String nuevaContrasena) async {
    contrasenas.add(nuevaContrasena);
    final e = error;
    if (e != null) throw RecuperacionExcepcion(e);
  }

  @override
  Future<void> cancelar() async => cancelaciones++;
}

ProviderContainer crearContenedor(RepositorioFalso repo) {
  final container = ProviderContainer(
    overrides: [recuperarContrasenaRepositorioProvider.overrideWithValue(repo)],
  );
  container.listen(recuperarContrasenaVistaModeloProvider, (_, _) {});
  container.listen(restablecerContrasenaVistaModeloProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Recupera tu contraseña', () {
    test('al pedir el enlace se muestra el aviso de CA-2', () async {
      final repo = RepositorioFalso();
      final c = crearContenedor(repo);

      await c.read(recuperarContrasenaVistaModeloProvider.notifier)
          .solicitarEnlace('ana@prueba.co');

      expect(repo.correos, ['ana@prueba.co']);
      final estado = c.read(recuperarContrasenaVistaModeloProvider);
      expect(estado.enviado, isTrue);
      expect(estado.error, isNull);
    });

    test('sin conexión no muestra el aviso de enviado', () async {
      final repo = RepositorioFalso()..error = ErrorRecuperacion.sinConexion;
      final c = crearContenedor(repo);

      await c.read(recuperarContrasenaVistaModeloProvider.notifier)
          .solicitarEnlace('ana@prueba.co');

      final estado = c.read(recuperarContrasenaVistaModeloProvider);
      expect(estado.enviado, isFalse);
      expect(estado.error, ErrorRecuperacion.sinConexion);
    });

    test('no envía dos veces mientras carga', () async {
      final repo = RepositorioFalso();
      final vm = crearContenedor(repo)
          .read(recuperarContrasenaVistaModeloProvider.notifier);

      await Future.wait([
        vm.solicitarEnlace('ana@prueba.co'),
        vm.solicitarEnlace('ana@prueba.co'),
      ]);
      expect(repo.correos, hasLength(1));
    });
  });

  group('Restablecer contraseña', () {
    test('contraseña cambiada → true (CA-6)', () async {
      final repo = RepositorioFalso();
      final c = crearContenedor(repo);

      final cambio = await c
          .read(restablecerContrasenaVistaModeloProvider.notifier)
          .restablecer('NuevaClave1!');

      expect(cambio, isTrue);
      expect(repo.contrasenas, ['NuevaClave1!']);
    });

    test('misma contraseña → false y error de dominio', () async {
      final repo = RepositorioFalso()..error = ErrorRecuperacion.mismaContrasena;
      final c = crearContenedor(repo);

      final cambio = await c
          .read(restablecerContrasenaVistaModeloProvider.notifier)
          .restablecer('Prueba123!');

      expect(cambio, isFalse);
      final estado = c.read(restablecerContrasenaVistaModeloProvider);
      expect(estado.error, ErrorRecuperacion.mismaContrasena);
      expect(estado.cargando, isFalse);
    });

    test('cancelar descarta la sesión temporal', () async {
      final repo = RepositorioFalso();
      final c = crearContenedor(repo);

      await c.read(restablecerContrasenaVistaModeloProvider.notifier).cancelar();
      expect(repo.cancelaciones, 1);
    });
  });
}
