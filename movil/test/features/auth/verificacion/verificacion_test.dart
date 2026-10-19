// Pruebas del RF-05 sin Supabase ni celular.
// Se corren con:   flutter test test/features/auth/verificacion/

import 'package:app_bienestar/features/auth/verificacion/data/verificacion_repositorio.dart';
import 'package:app_bienestar/features/auth/verificacion/domain/argumentos_verificacion.dart';
import 'package:app_bienestar/features/auth/verificacion/presentation/verificacion_vista_modelo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio falso: responde lo que la prueba le indique.
class RepositorioFalso implements VerificacionRepositorio {
  ErrorVerificacion? errorAlVerificar;
  int verificaciones = 0;
  int reenvios = 0;

  @override
  Future<void> verificar({
    required ArgumentosVerificacion argumentos,
    required String codigo,
  }) async {
    verificaciones++;
    final error = errorAlVerificar;
    if (error != null) throw VerificacionExcepcion(error);
  }

  @override
  Future<void> reenviar(ArgumentosVerificacion argumentos) async => reenvios++;
}

const argumentos = ArgumentosVerificacion(
  correo: 'ana@prueba.co',
  motivo: MotivoVerificacion.inicioSesion,
);

void main() {
  group('enmascararCorreo (CA-2)', () {
    test('deja ver solo las 2 primeras letras', () {
      expect(enmascararCorreo('juliana@correo.com'), 'ju•••@correo.com');
    });

    test('usuarios muy cortos muestran 1 letra', () {
      expect(enmascararCorreo('a@b.co'), 'a•••@b.co');
      expect(enmascararCorreo('ab@b.co'), 'a•••@b.co');
    });
  });

  group('ArgumentosVerificacion.desdeExtra', () {
    test('el correo que envía el registro es motivo registro', () {
      final a = ArgumentosVerificacion.desdeExtra('ana@prueba.co');
      expect(a?.motivo, MotivoVerificacion.registro);
      expect(a?.correo, 'ana@prueba.co');
    });

    test('sin datos devuelve null', () {
      expect(ArgumentosVerificacion.desdeExtra(null), isNull);
      expect(ArgumentosVerificacion.desdeExtra(''), isNull);
    });
  });

  group('VerificacionVistaModelo', () {
    late RepositorioFalso repo;
    late ProviderContainer container;

    VerificacionVistaModelo vm() =>
        container.read(verificacionVistaModeloProvider.notifier);

    setUp(() {
      repo = RepositorioFalso();
      container = ProviderContainer(
        overrides: [verificacionRepositorioProvider.overrideWithValue(repo)],
      );
      // autoDispose: se mantiene vivo mientras dure la prueba.
      container.listen(verificacionVistaModeloProvider, (_, _) {});
    });

    tearDown(() => container.dispose());

    test('arranca con la cuenta regresiva de 60 s (CA-5)', () {
      expect(container.read(verificacionVistaModeloProvider).segundosParaReenviar, 60);
      expect(vm().puedeReenviar, isFalse);
    });

    test('código correcto → éxito (CA-8)', () async {
      await vm().verificar(argumentos, '123456');
      expect(container.read(verificacionVistaModeloProvider).exito, isTrue);
    });

    test('no llama al Back si el código no tiene 6 dígitos', () async {
      await vm().verificar(argumentos, '123');
      expect(repo.verificaciones, 0);
    });

    test('3 códigos incorrectos descartan la sesión (CA-6 / CA-7)', () async {
      repo.errorAlVerificar = ErrorVerificacion.codigoIncorrecto;

      await vm().verificar(argumentos, '111111');
      var estado = container.read(verificacionVistaModeloProvider);
      expect(estado.intentosFallidos, 1);
      expect(estado.descartada, isFalse);

      await vm().verificar(argumentos, '222222');
      await vm().verificar(argumentos, '333333');
      estado = container.read(verificacionVistaModeloProvider);
      expect(estado.intentosFallidos, 3);
      expect(estado.descartada, isTrue);

      // Ya descartada, no se vuelve a intentar.
      await vm().verificar(argumentos, '444444');
      expect(repo.verificaciones, 3);
    });

    test('sin conexión no cuenta como intento fallido', () async {
      repo.errorAlVerificar = ErrorVerificacion.sinConexion;
      await vm().verificar(argumentos, '123456');

      final estado = container.read(verificacionVistaModeloProvider);
      expect(estado.intentosFallidos, 0);
      expect(estado.error, ErrorVerificacion.sinConexion);
    });

    test('no se puede reenviar antes de que termine la cuenta regresiva', () async {
      await vm().reenviar(argumentos);
      expect(repo.reenvios, 0);
    });
  });
}
