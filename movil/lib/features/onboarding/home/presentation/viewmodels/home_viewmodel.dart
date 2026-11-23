import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/home_summary_model.dart';
import '../../data/repositories/home_repository.dart';

/// ViewModel principal de la vista Home (MVVM).
/// Gestiona el estado reactivo de la pantalla sin acoplar la UI a los datos.
class HomeViewModel extends ChangeNotifier {
  final HomeRepository _repository;
  final DateTime Function() _ahora;
  StreamSubscription<AuthState>? _authSub;

  HomeSummaryModel _summary = HomeSummaryModel.initial();
  bool _isLoading = false;
  String? _errorMessage;

  HomeViewModel({HomeRepository? repository, DateTime Function()? ahora})
    : _repository = repository ?? MockHomeRepository(),
      _ahora = ahora ?? DateTime.now {
    loadSummary();
    _escucharCambiosDeSesion();
  }

  void _escucharCambiosDeSesion() {
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        loadSummary();
      });
    } catch (_) {
      // En pruebas sin Supabase inicializado no se suscribe al stream.
    }
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

  /// RF-07 CA-3: Fecha actual en formato largo, ej. "sábado, 26 de septiembre".
  String get fechaActual => formatearFechaLarga(_ahora());

  static const _diasSemana = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// Formatea [fecha] como "<día de semana>, <día> de <mes>".
  static String formatearFechaLarga(DateTime fecha) {
    final diaSemana = _diasSemana[fecha.weekday - 1];
    final mes = _meses[fecha.month - 1];
    return '$diaSemana, ${fecha.day} de $mes';
  }

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

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
