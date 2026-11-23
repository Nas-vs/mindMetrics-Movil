import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/juegos_repositorio.dart';
import '../../domain/juego.dart';
import '../../domain/sesion_juego.dart';

/// ViewModel para la sección de Catálogo de Juegos (RF-14).
class GamesViewModel extends ChangeNotifier {
  GamesViewModel({JuegosRepositorio? repositorio})
    : _repositorio = repositorio ?? _crearRepositorioPorDefecto() {
    cargarJuegos();
  }

  static JuegosRepositorio _crearRepositorioPorDefecto() {
    try {
      return JuegosRepositorio(Supabase.instance.client);
    } catch (_) {
      return JuegosRepositorio(null);
    }
  }

  final JuegosRepositorio _repositorio;

  List<Juego> _todosLosJuegos = [];
  ObjetivoJuego? _filtroSeleccionado; // null = 'Todos'
  bool _cargando = true;

  // Getters reactivos
  bool get cargando => _cargando;
  ObjetivoJuego? get filtroSeleccionado => _filtroSeleccionado;

  /// Retorna los juegos aplicando el filtro activo (CA-1, CA-2, CA-3).
  List<Juego> get juegosFiltrados {
    if (_filtroSeleccionado == null) return _todosLosJuegos;
    return _todosLosJuegos
        .where((j) => j.objetivo == _filtroSeleccionado)
        .toList();
  }

  /// Carga o recarga el catálogo de juegos.
  Future<void> cargarJuegos() async {
    _cargando = true;
    notifyListeners();

    _todosLosJuegos = await _repositorio.obtenerJuegos();
    _cargando = false;
    notifyListeners();
  }

  /// Cambia el filtro activo cuando el usuario toca un chip (CA-2).
  void seleccionarFiltro(ObjetivoJuego? objetivo) {
    if (_filtroSeleccionado == objetivo) {
      // Si toca el que ya está activo, vuelve a "Todos"
      _filtroSeleccionado = null;
    } else {
      _filtroSeleccionado = objetivo;
    }
    notifyListeners();
  }

  /// CA-8: Guarda la sesión completada a través del repositorio.
  Future<void> guardarSesion(SesionJuego sesion) async {
    await _repositorio.registrarSesionJuego(sesion);
  }
}
