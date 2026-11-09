import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Si el usuario de la sesión ya hizo la encuesta inicial (avatar o
/// formulario), para que el router lo lleve a /avatar al entrar.
enum SituacionEvaluacion {
  /// Sin sesión, consultando, o la consulta falló: no se redirige.
  desconocida,

  /// No hay fila en `evaluaciones_iniciales`: se abre el avatar.
  pendiente,

  /// Ya existe la fila (una por usuario).
  completa,

  /// No aceptó la conversación: va al Inicio y no se le vuelve a insistir
  /// hasta el próximo inicio de sesión (mientras llega el formulario).
  omitida,
}

/// Estado de la encuesta inicial que necesita el router.
///
/// Se recalcula solo cuando cambia el USUARIO de la sesión (iniciar o
/// cerrar sesión); los refrescos de token no consultan la base.
/// La consulta pasa por RLS ("cada usuario ve su evaluacion inicial").
class EstadoEvaluacionInicial extends ChangeNotifier {
  EstadoEvaluacionInicial({
    required this._usuarioActual,
    required this._yaTieneEvaluacion,
    Stream<Object?>? cambiosDeSesion,
  }) {
    _suscripcion = cambiosDeSesion?.listen((_) => revisar(), onError: (Object _) {});
    revisar();
  }

  /// Versión de la app: lee la sesión de Supabase y consulta
  /// `evaluaciones_iniciales`.
  factory EstadoEvaluacionInicial.supabase(SupabaseClient cliente) =>
      EstadoEvaluacionInicial(
        usuarioActual: () => cliente.auth.currentUser?.id,
        cambiosDeSesion: cliente.auth.onAuthStateChange,
        yaTieneEvaluacion: (id) async {
          final fila = await cliente
              .from('evaluaciones_iniciales')
              .select('id')
              .eq('usuario_id', id)
              .limit(1)
              .maybeSingle();
          return fila != null;
        },
      );

  final String? Function() _usuarioActual;
  final Future<bool> Function(String usuarioId) _yaTieneEvaluacion;
  StreamSubscription<Object?>? _suscripcion;

  String? _usuario;
  SituacionEvaluacion _situacion = SituacionEvaluacion.desconocida;

  SituacionEvaluacion get situacion => _situacion;

  /// `true` solo cuando se confirmó que falta la encuesta.
  bool get pendiente => _situacion == SituacionEvaluacion.pendiente;

  /// Vuelve a consultar si cambió el usuario de la sesión.
  Future<void> revisar() async {
    final usuario = _usuarioActual();
    if (usuario == _usuario) return;
    _usuario = usuario;
    _cambiar(SituacionEvaluacion.desconocida);
    if (usuario == null) return;

    SituacionEvaluacion nueva;
    try {
      nueva = await _yaTieneEvaluacion(usuario)
          ? SituacionEvaluacion.completa
          : SituacionEvaluacion.pendiente;
    } catch (_) {
      // Sin red o error del servidor: mejor dejarlo entrar al Inicio que
      // bloquearlo en el avatar.
      nueva = SituacionEvaluacion.desconocida;
    }
    // Mientras se consultaba pudo cerrar sesión o entrar otro usuario.
    if (_usuario == usuario) _cambiar(nueva);
  }

  /// La conversación guardó la evaluación.
  void marcarCompleta() => _cambiar(SituacionEvaluacion.completa);

  /// No aceptó conversar (eligió formulario o canceló).
  void omitirPorAhora() {
    if (_situacion != SituacionEvaluacion.completa) _cambiar(SituacionEvaluacion.omitida);
  }

  void _cambiar(SituacionEvaluacion s) {
    if (s == _situacion) return;
    _situacion = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
