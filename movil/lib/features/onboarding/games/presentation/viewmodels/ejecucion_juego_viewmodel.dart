import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/juego.dart';
import '../../domain/sesion_juego.dart';

/// Fases del ciclo de vida de un juego (RF-15).
enum FaseJuego {
  intro, // CA-1: Objetivos, cómo se juega y ánimo inicial
  jugando, // CA-2: Modo pantalla completa activo
  pausado, // CA-4, CA-5, CA-6: Pausa manual o automática
  finalizado, // CA-7: Cierre, ánimo final y comparativa
}

/// ViewModel para la ejecución común de cualquier juego (RF-15).
class EjecucionJuegoViewModel extends ChangeNotifier {
  EjecucionJuegoViewModel({required this.juego});

  final Juego juego;

  FaseJuego _fase = FaseJuego.intro;
  int? _animoInicial; // 1 a 5 (CA-1)
  int? _animoFinal; // 1 a 5 (CA-7)
  int _segundosTranscurridos = 0;
  Timer? _cronometro;

  // Getters reactivos
  FaseJuego get fase => _fase;
  int? get animoInicial => _animoInicial;
  int? get animoFinal => _animoFinal;
  int get segundosTranscurridos => _segundosTranscurridos;

  /// CA-1: Elige el ánimo previo o null si decide omitir.
  void seleccionarAnimoInicial(int? nivel) {
    _animoInicial = nivel;
    notifyListeners();
  }

  /// Inicia el juego y arranca el conteo de tiempo (CA-2).
  void comenzarJuego() {
    _fase = FaseJuego.jugando;
    _iniciarCronometro();
    notifyListeners();
  }

  /// CA-4, CA-5, CA-6: Pausa el juego (por botón, por 'Atrás' o por segundo plano).
  void pausarJuego() {
    if (_fase != FaseJuego.jugando) return;
    _fase = FaseJuego.pausado;
    _detenerCronometro();
    notifyListeners();
  }

  /// Reanuda la partida desde donde quedó.
  void reanudarJuego() {
    if (_fase != FaseJuego.pausado) return;
    _fase = FaseJuego.jugando;
    _iniciarCronometro();
    notifyListeners();
  }

  /// Reinicia la partida desde cero manteniendo el ánimo inicial.
  void reiniciarJuego() {
    _segundosTranscurridos = 0;
    _fase = FaseJuego.jugando;
    _iniciarCronometro();
    notifyListeners();
  }

  /// CA-7: Finaliza el juego y pasa a la pantalla de cierre.
  void finalizarJuego() {
    _fase = FaseJuego.finalizado;
    _detenerCronometro();
    notifyListeners();
  }

  /// CA-7: Registra el ánimo posterior para comparar.
  void seleccionarAnimoFinal(int nivel) {
    _animoFinal = nivel;
    notifyListeners();
  }

  /// CA-8: Genera el objeto final de sesión para guardar en la base de datos.
  SesionJuego generarSesion() {
    return SesionJuego(
      id: UniqueKey().toString(),
      juegoId: juego.id,
      animoInicial: _animoInicial,
      animoFinal: _animoFinal,
      duracionSegundos: _segundosTranscurridos,
      completado: _fase == FaseJuego.finalizado,
      fecha: DateTime.now(),
    );
  }

  void _iniciarCronometro() {
    _cronometro?.cancel();
    _cronometro = Timer.periodic(const Duration(seconds: 1), (_) {
      _segundosTranscurridos++;
      notifyListeners();
    });
  }

  void _detenerCronometro() {
    _cronometro?.cancel();
    _cronometro = null;
  }

  @override
  void dispose() {
    _detenerCronometro();
    super.dispose();
  }
}
