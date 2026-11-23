import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../animo/data/registro_animo_repositorio.dart';
import '../../data/models/home_summary_model.dart';
import '../../data/repositories/home_repository.dart';

/// ViewModel del Inicio (MVVM).
///
/// Recarga el resumen cuando:
/// - cambia la sesión (RF-07: el nickname viene del token),
/// - se guarda el ánimo del día ([animoGuardado], RF-08),
/// - la app vuelve a primer plano (el motor pudo terminar de calcular),
/// - el usuario desliza hacia abajo (RefreshIndicator).
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    HomeRepository? repository,
    DateTime Function()? ahora,
    Listenable? recargarCuando,
  })  : _repository = repository ?? HomeRepositorySupabase(),
        _ahora = ahora ?? DateTime.now,
        _recargarCuando = recargarCuando ?? animoGuardado {
    _recargarCuando.addListener(loadSummary);
    _ciclo = AppLifecycleListener(onResume: loadSummary);
    _escucharCambiosDeSesion();
    loadSummary();
  }

  final HomeRepository _repository;
  final DateTime Function() _ahora;
  final Listenable _recargarCuando;
  late final AppLifecycleListener _ciclo;
  StreamSubscription<AuthState>? _authSub;
  bool _destruido = false;
  int _peticion = 0;

  HomeSummaryModel _summary = HomeSummaryModel.initial();
  bool _isLoading = false;
  bool _cargoUnaVez = false;
  String? _errorMessage;

  void _escucharCambiosDeSesion() {
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) => loadSummary());
    } catch (_) {
      // En pruebas sin Supabase inicializado no se suscribe al stream.
    }
  }

  // Getters
  HomeSummaryModel get summary => _summary;
  bool get isLoading => _isLoading;

  /// true mientras se hace la PRIMERA carga (las siguientes no parpadean).
  bool get cargandoPrimeraVez => _isLoading && !_cargoUnaVez;
  String? get errorMessage => _errorMessage;

  String get username => _summary.username;

  /// "🙂 Bien" o "Sin registrar".
  String get estadoHoy {
    if (cargandoPrimeraVez) return '…';
    final n = _summary.nivelHoy;
    return n == null ? 'Sin registrar' : '${n.emoji} ${n.etiqueta}';
  }

  ResultadoEvaluacion get evaluacion => _summary.evaluacion;

  String get resultadoEvaluacion =>
      cargandoPrimeraVez ? '…' : _summary.evaluacion.textoCorto;

  String get racha {
    if (cargandoPrimeraVez) return '…';
    final r = _summary.racha;
    return r == 1 ? '1 DÍA' : '$r DÍAS';
  }

  List<DiaSemana> get semana => _summary.semana;

  String get tituloSemana => HomeSummaryModel.tituloSemana(_summary.semana, _ahora());

  DateTime get hoy => _ahora();

  /// RF-07 CA-3: fecha actual en formato largo, ej. "sábado, 26 de septiembre".
  String get fechaActual => formatearFechaLarga(_ahora());

  static const _diasSemana = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Formatea [fecha] como `<día de semana>, <día> de <mes>`.
  static String formatearFechaLarga(DateTime fecha) {
    final diaSemana = _diasSemana[fecha.weekday - 1];
    final mes = _meses[fecha.month - 1];
    return '$diaSemana, ${fecha.day} de $mes';
  }

  /// Carga las métricas del usuario. Si llegan dos recargas seguidas, solo
  /// se aplica la respuesta de la última.
  Future<void> loadSummary() async {
    final id = ++_peticion;
    _isLoading = true;
    _errorMessage = null;
    _avisar();

    try {
      final resumen = await _repository.getHomeSummary();
      if (id != _peticion) return;
      _summary = resumen;
    } catch (e) {
      if (id != _peticion) return;
      _errorMessage = 'Error al cargar los datos: $e';
    }
    _isLoading = false;
    _cargoUnaVez = true;
    _avisar();
  }

  void _avisar() {
    if (!_destruido) notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    _recargarCuando.removeListener(loadSummary);
    _ciclo.dispose();
    _authSub?.cancel();
    super.dispose();
  }
}
