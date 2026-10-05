import 'package:app_bienestar/features/auth/registro/domain/datos_registro.dart';
import 'package:app_bienestar/features/auth/registro/domain/validadores_registro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hoy = DateTime(2026, 10, 5);

  group('fechaNacimiento (regla del trigger crear_perfil_inicial)', () {
    test('PU-01: cumple 18 años exactamente hoy -> válida', () {
      expect(ValidadoresRegistro.fechaNacimiento(DateTime(2008, 10, 5), hoy), isNull);
    });
    test('PU-02: cumple 18 años mañana -> inválida', () {
      expect(ValidadoresRegistro.fechaNacimiento(DateTime(2008, 10, 6), hoy), isNotNull);
    });
    test('sin fecha -> inválida', () {
      expect(ValidadoresRegistro.fechaNacimiento(null, hoy), isNotNull);
    });
  });

  group('contrasena', () {
    test('PU-03: sin carácter especial no cumple esa regla', () {
      final reglas = ValidadoresRegistro.reglasContrasena('Abcdefg1');
      expect(reglas['Un carácter especial'], isFalse);
      expect(ValidadoresRegistro.contrasena('Abcdefg1'), isNotNull);
    });
    test('cumple todas las reglas -> válida', () {
      expect(ValidadoresRegistro.contrasena('Abcdef1!'), isNull);
    });
    test('confirmación distinta -> inválida', () {
      expect(ValidadoresRegistro.confirmarContrasena('Abcdef1?', 'Abcdef1!'), isNotNull);
    });
  });

  group('nickname (CHECK perfiles_nickname_formato)', () {
    test('PU-04: con espacio -> inválido', () {
      expect(ValidadoresRegistro.nickname('ana p'), isNotNull);
    });
    test('2 caracteres -> inválido', () {
      expect(ValidadoresRegistro.nickname('an'), isNotNull);
    });
    test('21 caracteres -> inválido', () {
      expect(ValidadoresRegistro.nickname('a' * 21), isNotNull);
    });
    test('válido', () {
      expect(ValidadoresRegistro.nickname('ana_95'), isNull);
    });
  });

  group('nombreCompleto (CHECK perfiles_nombre_completo_formato)', () {
    test('con tildes y ñ -> válido', () {
      expect(ValidadoresRegistro.nombreCompleto('José Muñoz'), isNull);
    });
    test('con números -> inválido', () {
      expect(ValidadoresRegistro.nombreCompleto('Ana 2'), isNotNull);
    });
    test('61 caracteres -> inválido', () {
      expect(ValidadoresRegistro.nombreCompleto('a' * 61), isNotNull);
    });
  });

  group('correo', () {
    test('PU-05: sin dominio -> inválido', () {
      expect(ValidadoresRegistro.correo('ana@'), isNotNull);
    });
    test('válido', () {
      expect(ValidadoresRegistro.correo('ana@correo.com'), isNull);
    });
  });

  group('DatosRegistro.aMetadatos (contrato con los triggers)', () {
    final datos = DatosRegistro(
      nombreCompleto: '  Ana Prueba ',
      nickname: ' ana ',
      correo: ' Ana@Correo.COM ',
      contrasena: 'Abcdef1!',
      fechaNacimiento: DateTime(1995, 5, 5),
      versionPolitica: '1.0',
    );

    test('envía exactamente las 5 claves que leen los triggers', () {
      expect(datos.aMetadatos().keys.toSet(), {
        'nombre_completo',
        'nickname',
        'fecha_nacimiento',
        'acepta_datos_sensibles',
        'version_politica',
      });
    });
    test('normaliza valores', () {
      final m = datos.aMetadatos();
      expect(m['nombre_completo'], 'Ana Prueba');
      expect(m['nickname'], 'ana');
      expect(m['fecha_nacimiento'], '1995-05-05');
      expect(m['acepta_datos_sensibles'], isTrue);
      expect(datos.correoNormalizado, 'ana@correo.com');
    });
  });
}
