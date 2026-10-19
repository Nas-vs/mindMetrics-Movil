import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Identificador de ESTE celular para RF-04/RF-05 ("dispositivo conocido").
///
/// Se genera una sola vez (UUID aleatorio) y se guarda en el almacenamiento
/// seguro del sistema (Keystore en Android, Keychain en iOS). No identifica
/// a la persona ni al hardware: si se reinstala la app, se genera otro y el
/// Back vuelve a pedir el código, que es lo esperado.
///
/// Lo usan:
/// - la Edge Function `bloqueo-login` (campo `dispositivo_id`), para saber si
///   puede saltarse el código;
/// - la RPC `registrar_dispositivo`, después de verificar el código.
class IdentificadorDispositivo {
  IdentificadorDispositivo([FlutterSecureStorage? almacen])
      : _almacen = almacen ?? const FlutterSecureStorage();

  static const _clave = 'dispositivo_id';

  final FlutterSecureStorage _almacen;
  String? _enMemoria;

  Future<String> obtener() async {
    final enMemoria = _enMemoria;
    if (enMemoria != null) return enMemoria;

    var id = await _almacen.read(key: _clave);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _almacen.write(key: _clave, value: id);
    }
    return _enMemoria = id;
  }
}

/// En las pruebas se reemplaza con `overrideWithValue(...)`.
final identificadorDispositivoProvider = Provider<IdentificadorDispositivo>(
  (ref) => IdentificadorDispositivo(),
);
