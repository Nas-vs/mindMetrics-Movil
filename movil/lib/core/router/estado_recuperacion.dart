import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado del flujo de recuperación de contraseña (RF-06) que necesita el
/// router.
///
/// Cuando el usuario toca el enlace del correo, `supabase_flutter` abre la
/// app con `mindmetrics://restablecer-contrasena?code=...`, crea una sesión
/// temporal y emite [AuthChangeEvent.passwordRecovery]. Desde ese momento,
/// y hasta que cambie la contraseña o cancele, el router solo permite la
/// pantalla "Restablecer contraseña".
///
/// Si el enlace venció o ya se usó (CA-7), Supabase emite un error en el
/// mismo stream: se marca [enlaceInvalido] y el router muestra la pantalla
/// de recuperar contraseña con el aviso.
class EstadoRecuperacion extends ChangeNotifier {
  EstadoRecuperacion(Stream<AuthState> eventos) {
    _suscripcion = eventos.listen(_alEvento, onError: _alError);
  }

  late final StreamSubscription<AuthState> _suscripcion;

  bool _activa = false;
  bool _enlaceInvalido = false;

  /// true entre el enlace del correo y el cambio de contraseña.
  bool get activa => _activa;

  /// true cuando el enlace del correo ya no sirve (CA-7).
  bool get enlaceInvalido => _enlaceInvalido;

  void _alEvento(AuthState estado) {
    switch (estado.event) {
      case AuthChangeEvent.passwordRecovery:
        _activa = true;
        _enlaceInvalido = false;
        notifyListeners();
      case AuthChangeEvent.signedOut:
        if (_activa) {
          _activa = false;
          notifyListeners();
        }
      default:
        break;
    }
  }

  void _alError(Object error) {
    if (esErrorDeEnlace(error)) {
      _enlaceInvalido = true;
      notifyListeners();
    }
  }

  /// La pantalla ya mostró el aviso de enlace inválido.
  void limpiarEnlaceInvalido() {
    if (!_enlaceInvalido) return;
    _enlaceInvalido = false;
    notifyListeners();
  }

  /// Distingue los errores del enlace del correo de otros errores de Auth
  /// que viajan por el mismo stream (p. ej. un refresh token vencido).
  @visibleForTesting
  static bool esErrorDeEnlace(Object error) {
    if (error is AuthPKCEGrantCodeExchangeError) return true;
    if (error is! AuthException) return false;
    const codigos = {
      'access_denied', // ?error=access_denied en la URL de redirección
      'otp_expired',
      'flow_state_not_found',
      'flow_state_expired',
      'bad_code_verifier',
    };
    return codigos.contains(error.code) ||
        codigos.contains(error.statusCode) ||
        error.message.contains('Code verifier');
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}
