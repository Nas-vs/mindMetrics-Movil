import 'package:flutter/material.dart';

/// ViewModel para controlar la navegación y la pestaña activa del Shell principal.
class MainShellModel extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void selectTab(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
