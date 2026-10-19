import 'package:flutter/material.dart';
import '../../data/models/home_summary_model.dart';
import '../../data/repositories/home_repository.dart';

/// ViewModel para la pantalla de Home (patrón MVVM).
class HomeViewModel extends ChangeNotifier {
  final HomeRepository _repository;

  HomeSummaryModel _summary = HomeSummaryModel.initial();
  bool _isLoading = false;
  String? _errorMessage;

  HomeViewModel({HomeRepository? repository})
      : _repository = repository ?? MockHomeRepository() {
    loadSummary();
  }

  // Getters
  HomeSummaryModel get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get username => _summary.username;
  String get estadoHoy => _summary.estadoHoy;
  String get registroEstimado => _summary.registroEstimado;
  String get rachaDias => _summary.rachaDias;
  String get rachaTexto => _summary.rachaTexto;

  /// Carga las métricas del usuario.
  Future<void> loadSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _repository.getHomeSummary();
    } catch (e) {
      _errorMessage = 'Error al cargar los datos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Permite actualizar variables dinámicamente cuando el usuario complete una encuesta o juego.
  void updateMetrics({
    String? estadoHoy,
    String? registroEstimado,
    String? rachaDias,
    String? rachaTexto,
  }) {
    _summary = _summary.copyWith(
      estadoHoy: estadoHoy,
      registroEstimado: registroEstimado,
      rachaDias: rachaDias,
      rachaTexto: rachaTexto,
    );
    notifyListeners();
  }
}
