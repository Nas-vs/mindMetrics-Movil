import '../models/home_summary_model.dart';

/// Repositorio abstracto para abstraer la fuente de datos del Home.
abstract class HomeRepository {
  Future<HomeSummaryModel> getHomeSummary();
}

/// Implementación concreta (Mock) lista para conectar a Supabase/API en el futuro.
class MockHomeRepository implements HomeRepository {
  @override
  Future<HomeSummaryModel> getHomeSummary() async {
    // Simula una breve espera de red si fuera necesario
    await Future.delayed(const Duration(milliseconds: 100));
    return HomeSummaryModel.initial();
  }
}
