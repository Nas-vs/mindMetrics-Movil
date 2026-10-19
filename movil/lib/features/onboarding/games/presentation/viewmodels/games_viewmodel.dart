import 'package:flutter/material.dart';

/// ViewModel para la sección de Juegos.
class GamesViewModel extends ChangeNotifier {
  final bool _isLoading = false;
  final List<String> _availableGames = const [
    'Juego de Memoria',
    'Test de Reacción',
    'Desafío Mental',
  ];

  bool get isLoading => _isLoading;
  List<String> get availableGames => _availableGames;

  void refreshGames() {
    notifyListeners();
  }
}
