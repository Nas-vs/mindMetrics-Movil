import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RF-01 CA-4: recuerda en el celular si ya se vio la bienvenida.
///
/// El router lo escucha: mientras [pendiente] sea true y no haya sesión,
/// la app abre en /bienvenida.
class EstadoBienvenida extends ChangeNotifier {
  EstadoBienvenida._(this._preferencias, this._pendiente);

  static const clave = 'onboarding_completado';

  final SharedPreferences _preferencias;
  bool _pendiente;

  /// Lee la marca guardada. Se llama una vez en main(), antes del router.
  static Future<EstadoBienvenida> cargar() async {
    final preferencias = await SharedPreferences.getInstance();
    final completado = preferencias.getBool(clave) ?? false;
    return EstadoBienvenida._(preferencias, !completado);
  }

  /// true: aún no se ha visto (primera vez en este celular).
  bool get pendiente => _pendiente;

  /// "Comenzar" o "Saltar": no se vuelve a mostrar.
  Future<void> completar() async {
    if (!_pendiente) return;
    _pendiente = false;
    notifyListeners();
    await _preferencias.setBool(clave, true);
  }
}
