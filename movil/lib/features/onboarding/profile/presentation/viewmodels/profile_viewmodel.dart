import 'package:flutter/material.dart';

/// ViewModel para la sección de Perfil de Usuario.
class ProfileViewModel extends ChangeNotifier {
  String _userName = 'Usuario';
  String _email = 'usuario@mindmetrics.com';

  String get userName => _userName;
  String get email => _email;

  void updateProfile({String? name, String? email}) {
    if (name != null) _userName = name;
    if (email != null) _email = email;
    notifyListeners();
  }
}
