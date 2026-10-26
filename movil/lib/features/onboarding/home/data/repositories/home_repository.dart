import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/home_summary_model.dart';

/// Repositorio abstracto para abstraer la fuente de datos del Home.
abstract class HomeRepository {
  Future<HomeSummaryModel> getHomeSummary();
}

/// Implementación del repositorio de Inicio.
///
/// RF-07 CA-2: el nickname se lee directamente de la sesión en memoria
/// (`currentUser.appMetadata['nickname']`, sincronizado por el trigger de
/// RF-07 en el Back) sin hacer ninguna petición adicional a la red.
class MockHomeRepository implements HomeRepository {
  MockHomeRepository({String? Function()? obtenerNickname})
    : _obtenerNickname = obtenerNickname ?? _leerNicknameDeSesion;

  final String? Function() _obtenerNickname;

  static String? _leerNicknameDeSesion() {
    try {
      final meta = Supabase.instance.client.auth.currentUser?.appMetadata;
      final nickname = meta?['nickname'];
      if (nickname is String && nickname.trim().isNotEmpty) {
        return nickname.trim();
      }
    } catch (_) {
      // Si Supabase no está inicializado (ej. en una prueba de widgets),
      // usa el valor por defecto.
    }
    return null;
  }

  @override
  Future<HomeSummaryModel> getHomeSummary() async {
    final nickname = _obtenerNickname() ?? 'Usuario';
    return HomeSummaryModel.initial().copyWith(username: nickname);
  }
}
