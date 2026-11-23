import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lugar donde se guardan textos en el celular.
///
/// En la app es el almacenamiento seguro (ya lo usa el equipo para el
/// identificador del dispositivo); en las pruebas, un mapa en memoria.
abstract class AlmacenClaveValor {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
}

class AlmacenSeguro implements AlmacenClaveValor {
  AlmacenSeguro([FlutterSecureStorage? almacen])
      : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  @override
  Future<String?> leer(String clave) => _almacen.read(key: clave);

  @override
  Future<void> escribir(String clave, String valor) =>
      _almacen.write(key: clave, value: valor);
}

/// Para pruebas.
class AlmacenEnMemoria implements AlmacenClaveValor {
  final datos = <String, String>{};

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async => datos[clave] = valor;
}
