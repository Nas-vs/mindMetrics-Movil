import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/perfil_repositorio.dart';
import '../../domain/perfil_usuario.dart';

/// ViewModel para la sección de Perfil de Usuario (RF-23).
/// Gestiona la lectura y actualización de los datos del usuario.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({PerfilRepositorio? repositorio})
    : _repositorio = repositorio ?? _crearRepositorioPorDefecto() {
    cargarPerfil();
  }

  static PerfilRepositorio _crearRepositorioPorDefecto() {
    try {
      return PerfilRepositorio(Supabase.instance.client);
    } catch (_) {
      return PerfilRepositorio(null);
    }
  }

  final PerfilRepositorio _repositorio;

  PerfilUsuario? _perfil;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  // Getters para que la vista los lea reactivamente
  PerfilUsuario? get perfil => _perfil;
  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;

  String get userName => _perfil?.nombreCompleto ?? 'Usuario';
  String get nickname => _perfil?.nickname ?? '';
  String get email => _perfil?.correo ?? '';
  String get iniciales => _perfil?.iniciales ?? '?';
  String get fechaRegistro => _perfil?.fechaRegistroFormateada ?? '';

  /// CA-1: Consulta los datos del perfil en Supabase.
  Future<void> cargarPerfil() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _perfil = await _repositorio.obtenerPerfil();
    } on PerfilExcepcion catch (e) {
      _error = e.mensaje ?? _mensajeError(e.tipo);
    } catch (_) {
      _error = 'No se pudo cargar la información del perfil.';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// CA-2: Actualiza el nombre y nickname en Supabase.
  /// Devuelve true si la actualización fue exitosa.
  Future<bool> actualizarPerfil({
    required String nuevoNombre,
    required String nuevoNickname,
  }) async {
    _guardando = true;
    _error = null;
    notifyListeners();

    try {
      _perfil = await _repositorio.actualizarPerfil(
        nuevoNombre: nuevoNombre,
        nuevoNickname: nuevoNickname,
      );
      _guardando = false;
      notifyListeners();
      return true;
    } on PerfilExcepcion catch (e) {
      _error = e.mensaje ?? _mensajeError(e.tipo);
      _guardando = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Ocurrió un error inesperado al actualizar.';
      _guardando = false;
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    _error = null;
  }

  String _mensajeError(ErrorPerfil tipo) => switch (tipo) {
    ErrorPerfil.nicknameOcupado =>
      'Este nickname ya está en uso por otro usuario.',
    ErrorPerfil.formatoInvalido =>
      'Nombre o nickname no cumplen con las reglas.',
    ErrorPerfil.sinConexion =>
      'Sin conexión. Revisa tu internet e intenta de nuevo.',
    ErrorPerfil.sesionRequerida => 'Debes iniciar sesión para ver tu perfil.',
    ErrorPerfil.servidor => 'Error en el servidor. Intenta más tarde.',
  };
}
