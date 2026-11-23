import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/registro_animo_repositorio.dart';
import '../domain/registro_animo.dart';

/// Estado de la pantalla de registro rápido de ánimo (RF-08).
class RegistroAnimoVistaModelo extends ChangeNotifier {
  RegistroAnimoVistaModelo(this._repo, {DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final RegistroAnimoRepositorio _repo;
  final DateTime Function() _reloj;

  bool cargando = true;
  bool guardando = false;
  bool panelAbierto = false; // CA-4: el detalle es opcional
  bool esEdicion = false; // CA-3: ya había registro hoy

  List<OpcionCatalogo> emociones = const [];
  List<OpcionCatalogo> factores = const [];

  int? nivel;
  Set<int> emocionesElegidas = {};
  Set<int> factoresElegidos = {};
  String nota = '';

  String? _id;
  String? aviso;
  bool _destruido = false;

  static const maxNota = 500; // mismo CHECK que la tabla

  bool get puedeGuardar => nivel != null && !guardando;

  Future<void> cargar() async {
    final hoy = fechaLocal(_reloj());
    try {
      await _repo.sincronizarPendientes();
    } catch (_) {/* se reintenta al guardar */}
    try {
      final r = await Future.wait([
        _repo.emociones(),
        _repo.factores(),
        _repo.registroDe(hoy),
      ]);
      emociones = r[0] as List<OpcionCatalogo>;
      factores = r[1] as List<OpcionCatalogo>;
      final existente = r[2] as RegistroAnimo?;
      if (existente != null) {
        esEdicion = true;
        _id = existente.id;
        nivel = existente.nivel;
        emocionesElegidas = {...existente.emociones};
        factoresElegidos = {...existente.factores};
        nota = existente.nota ?? '';
        panelAbierto = emocionesElegidas.isNotEmpty ||
            factoresElegidos.isNotEmpty ||
            nota.isNotEmpty;
      }
    } catch (_) {
      // Sin red al abrir: igual se puede registrar el nivel (offline).
      aviso = 'Sin conexión: tu registro se guardará en el celular.';
    }
    cargando = false;
    _avisar();
  }

  void elegirNivel(int valor) {
    nivel = valor;
    _avisar();
  }

  void alternarPanel() {
    panelAbierto = !panelAbierto;
    _avisar();
  }

  void alternarEmocion(int id) {
    emocionesElegidas.contains(id)
        ? emocionesElegidas.remove(id)
        : emocionesElegidas.add(id);
    _avisar();
  }

  void alternarFactor(int id) {
    factoresElegidos.contains(id)
        ? factoresElegidos.remove(id)
        : factoresElegidos.add(id);
    _avisar();
  }

  void cambiarNota(String texto) => nota = texto;

  /// Devuelve el resultado, o null si el servidor lo rechazó.
  Future<ResultadoGuardado?> guardar() async {
    if (!puedeGuardar) return null;
    guardando = true;
    _avisar();
    final registro = RegistroAnimo(
      id: _id ??= const Uuid().v4(),
      fecha: fechaLocal(_reloj()),
      nivel: nivel!,
      emociones: {...emocionesElegidas},
      factores: {...factoresElegidos},
      nota: nota.trim().isEmpty ? null : nota.trim(),
      actualizadoEnCliente: _reloj(),
    );
    try {
      final resultado = await _repo.guardar(registro);
      esEdicion = true;
      return resultado;
    } on PostgrestException catch (e) {
      aviso = _mensajeError(e.message);
      return null;
    } finally {
      guardando = false;
      _avisar();
    }
  }

  /// CA-8: después de guardar, ¿hay una alerta de bienestar que mostrar?
  Future<AlertaBienestar?> alertaPendiente() async {
    try {
      return await _repo.alertaPendiente();
    } catch (_) {
      return null; // Sin red no hay alerta; el trigger ya la guardó en el server.
    }
  }

  Future<void> marcarAlertaVista(String id) async {
    try {
      await _repo.marcarAlertaVista(id);
    } catch (_) {}
  }

  void limpiarAviso() => aviso = null;

  static String _mensajeError(String codigo) => switch (codigo) {
        'nota_muy_larga' => 'La nota puede tener máximo $maxNota caracteres.',
        'sesion_requerida' => 'Tu sesión terminó. Vuelve a iniciar sesión.',
        'fecha_futura' => 'Revisa la fecha y hora de tu celular.',
        _ => 'No pudimos guardar tu registro. Intenta de nuevo.',
      };

  void _avisar() {
    if (!_destruido) notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }
}
