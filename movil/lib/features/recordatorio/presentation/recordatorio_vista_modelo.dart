import 'package:flutter/foundation.dart';

import '../data/recordatorio_servicio.dart';
import '../domain/preferencias_recordatorio.dart';

/// Estado de la pantalla de configuración del recordatorio (RF-22).
class RecordatorioVistaModelo extends ChangeNotifier {
  RecordatorioVistaModelo(this._servicio);

  final RecordatorioServicio _servicio;

  bool cargando = true;
  bool ocupado = false;
  PreferenciasRecordatorio preferencias = const PreferenciasRecordatorio();

  /// Mensaje para mostrar en un Snackbar (luego se limpia).
  String? aviso;

  bool _destruido = false;

  Future<void> cargar() async {
    preferencias = await _servicio.leerPreferencias();
    cargando = false;
    _avisar();
  }

  Future<void> cambiarActivo(bool activo) => _hacer(() async {
        if (activo) {
          final concedido = await _servicio.activar();
          if (!concedido) {
            aviso = 'Para recibir el recordatorio, permite las notificaciones '
                'de MindMetrics en los ajustes del celular.';
          }
        } else {
          await _servicio.desactivar();
        }
      });

  Future<void> cambiarHora(int hora, int minuto) =>
      _hacer(() => _servicio.cambiarHora(hora, minuto));

  Future<void> probar() => _hacer(() async {
        await _servicio.probarAhora();
        aviso = 'Notificación enviada. Tócala para ir al registro de ánimo.';
      });

  /// Solo para probar CA-1 mientras no existe la pantalla de RF-08.
  Future<void> simularRegistro(Future<bool> Function() preguntar) =>
      _hacer(() => _servicio.despuesDeRegistrarAnimo(preguntarAlUsuario: preguntar));

  void limpiarAviso() => aviso = null;

  Future<void> _hacer(Future<void> Function() accion) async {
    ocupado = true;
    _avisar();
    try {
      await accion();
    } catch (_) {
      aviso = 'No pudimos actualizar el recordatorio. Intenta de nuevo.';
    }
    preferencias = await _servicio.leerPreferencias();
    ocupado = false;
    _avisar();
  }

  void _avisar() {
    if (!_destruido) notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }
}
