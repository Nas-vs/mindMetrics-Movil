import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/jardin_repositorio.dart';
import '../../domain/planta.dart';

/// ViewModel para la pantalla del Jardín Emocional (RF-16).
class JardinViewModel extends ChangeNotifier {
  JardinViewModel({JardinRepositorio? repositorio})
    : _repositorio = repositorio ?? _crearRepositorioPorDefecto() {
    cargarJardin();
  }

  static JardinRepositorio _crearRepositorioPorDefecto() {
    try {
      return JardinRepositorio(Supabase.instance.client);
    } catch (_) {
      return JardinRepositorio(null);
    }
  }

  final JardinRepositorio _repositorio;

  Planta? _planta;
  int _gotasDisponibles = 0;
  int _diasRacha = 0;
  bool _cargando = true;
  bool _regando = false;
  String? _mensajeAnimo;
  bool _mostrarMensajeEsperando = false;

  // Getters reactivos
  Planta? get planta => _planta;
  bool get tienePlanta => _planta != null;
  int get gotasDisponibles => _gotasDisponibles;
  int get diasRacha => _diasRacha;
  bool get cargando => _cargando;
  bool get regando => _regando;
  String? get mensajeAnimo => _mensajeAnimo;
  bool get mostrarMensajeEsperando => _mostrarMensajeEsperando;

  /// CA-5: Lista de decoraciones desbloqueadas según la racha actual.
  List<DecoracionJardin> get decoracionesDesbloqueadas {
    return DecoracionJardin.values
        .where((d) => _diasRacha >= d.diasRequeridos)
        .toList();
  }

  /// Carga inicial del jardín y comprobación de ausencia (CA-4).
  Future<void> cargarJardin() async {
    _cargando = true;
    notifyListeners();

    _planta = await _repositorio.obtenerPlanta();

    if (_planta != null && _repositorio.estabaAusente(_planta)) {
      _mostrarMensajeEsperando = true; // CA-4
    }

    _diasRacha = await _repositorio.obtenerDiasRacha();
    _gotasDisponibles = await _repositorio.obtenerGotasDisponibles(
      _planta?.totalRiegos ?? 0,
    );

    _cargando = false;
    notifyListeners();
  }

  /// CA-1: Adopta la primera planta del usuario con su nombre.
  Future<void> adoptarPlanta(TipoPlanta tipo, String nombre) async {
    final nuevaPlanta = Planta(
      id: UniqueKey().toString(),
      nombre: nombre.trim().isEmpty ? tipo.nombre : nombre.trim(),
      tipo: tipo,
      totalRiegos: 0,
      fechaCreacion: DateTime.now(),
      ultimoAcceso: DateTime.now(),
    );

    _planta = nuevaPlanta;
    await _repositorio.guardarPlanta(nuevaPlanta);
    _gotasDisponibles = await _repositorio.obtenerGotasDisponibles(0);
    notifyListeners();
  }

  /// CA-2 y CA-3: Riega la planta con animación si hay gotas disponibles.
  Future<bool> regarPlanta() async {
    if (_planta == null || _gotasDisponibles <= 0 || _regando) {
      return false;
    }

    _regando = true;
    notifyListeners();

    // Tiempo para la animación de las gotas cayendo
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final plantaActualizada = _planta!.regar();
    _planta = plantaActualizada;
    _gotasDisponibles--;

    await _repositorio.guardarPlanta(plantaActualizada);

    _regando = false;
    notifyListeners();
    return true;
  }

  /// CA-6: Al tocar la planta, muestra un mensaje aleatorio de bienestar.
  void tocarPlanta() {
    _mensajeAnimo = _repositorio.obtenerMensajeAleatorio();
    notifyListeners();
  }

  /// Cierra el mensaje emergente de ánimo.
  void cerrarMensajeAnimo() {
    _mensajeAnimo = null;
    notifyListeners();
  }

  /// Cierra el aviso de bienvenida tras ausencia.
  void descartarMensajeEsperando() {
    _mostrarMensajeEsperando = false;
    notifyListeners();
  }
}
