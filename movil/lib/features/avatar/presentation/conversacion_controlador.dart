import 'package:flutter/foundation.dart';

import '../domain/dialogo/guion.dart';
import '../domain/dialogo/sesion_dialogo.dart';
import '../domain/estado_avatar.dart';
import '../domain/servicio_voz.dart';
import 'avatar_controlador.dart';

enum EstadoConversacion {
  inactiva,
  hablando,
  escuchando,

  /// Espera que el usuario escriba o toque una opción.
  esperandoTexto,

  /// Varios silencios seguidos: se dejó de escuchar hasta que toque "Seguir".
  pausada,
  guardando,
  terminada,

  /// Se mostró la ayuda de crisis; sigue si dice "sigamos".
  crisis,

  /// Pidió el formulario clásico.
  formulario,
  error,
}

class MensajeChat {
  const MensajeChat({required this.deAvatar, required this.texto});
  final bool deAvatar;
  final String texto;
}

/// Orquesta un turno completo: el avatar habla (TTS), escucha (STT), la
/// [SesionDialogo] interpreta y, al final, se guarda la evaluación.
///
/// Mueve el [AvatarControlador]: hablando → escuchando → pensando.
class ConversacionControlador extends ChangeNotifier {
  ConversacionControlador({
    required Guion guion,
    required this.voz,
    required this.avatar,
    required this.guardar,
    String mascota = 'Nimbus',
    String? apodo,
    this.maxSilencios = 3,
  })  : sesion = SesionDialogo(guion, mascota: mascota, apodo: apodo),
        lineasCrisis = guion.crisis.lineas;

  final SesionDialogo sesion;
  final ServicioVoz voz;
  final AvatarControlador avatar;

  /// Guarda la fila final; en la app es `EvaluacionVozRepositorio.guardar`.
  final Future<void> Function(Map<String, Object> fila) guardar;
  final int maxSilencios;
  final List<LineaAyuda> lineasCrisis;

  EstadoConversacion _estado = EstadoConversacion.inactiva;
  EstadoConversacion get estado => _estado;

  Turno? _turno;
  Turno? get turno => _turno;

  final List<MensajeChat> _historial = [];
  List<MensajeChat> get historial => List.unmodifiable(_historial);

  Object? _error;
  Object? get error => _error;

  bool get huboCrisis => sesion.huboCrisis;

  int _silencios = 0;
  int _ciclo = 0; // cada interacción nueva invalida el ciclo anterior
  bool _cerrado = false;

  Future<void> iniciar() => _correr(sesion.iniciar());

  /// Respuesta escrita (o el texto reconocido, si la UI lo envía).
  Future<void> responderTexto(String texto) async {
    if (texto.trim().isEmpty || !_aceptaEntrada) return;
    await _cortarEscucha();
    _historial.add(MensajeChat(deAvatar: false, texto: texto.trim()));
    await _correr(sesion.responder(texto));
  }

  /// El usuario tocó una opción.
  Future<void> elegir(OpcionTurno opcion) async {
    if (!_aceptaEntrada) return;
    await _cortarEscucha();
    _historial.add(MensajeChat(deAvatar: false, texto: opcion.etiqueta));
    if (_turno?.tipo == TipoTurno.confirmacion) {
      // Sí/No de la confirmación: se responde como si lo hubiera dicho
      await _correr(sesion.responder(opcion.valor == true ? 'sí' : 'no'));
    } else {
      await _correr(sesion.elegir(opcion.valor));
    }
  }

  /// Retoma la escucha después de una pausa por silencio.
  Future<void> seguir() async {
    if (_estado != EstadoConversacion.pausada || _turno == null) return;
    _silencios = 0;
    await _escucharYResponder(++_ciclo);
  }

  /// Reintenta guardar tras un error.
  Future<void> reintentarGuardado() async {
    if (_estado == EstadoConversacion.error && sesion.terminada) await _guardar();
  }

  /// Se puede escribir o tocar incluso mientras habla: lo interrumpe.
  bool get _aceptaEntrada => sesion.esperaRespuesta && const {
        EstadoConversacion.hablando,
        EstadoConversacion.escuchando,
        EstadoConversacion.esperandoTexto,
        EstadoConversacion.pausada,
        EstadoConversacion.crisis,
      }.contains(_estado);

  Future<void> _correr(Turno turno) async {
    final ciclo = ++_ciclo;
    _turno = turno;
    _historial.add(MensajeChat(deAvatar: true, texto: turno.texto));
    _cambiar(EstadoConversacion.hablando);

    avatar.hablar(emocion: turno.emocion);
    await voz.hablar(turno.texto);
    if (_obsoleto(ciclo)) return;
    avatar.detener();

    switch (turno.tipo) {
      case TipoTurno.fin:
        await _guardar();
      case TipoTurno.formulario:
        _cambiar(EstadoConversacion.formulario);
      case TipoTurno.crisis:
        _cambiar(EstadoConversacion.crisis);
        // Sigue escuchando por si dice "sigamos"; la UI muestra las líneas.
        if (voz.admiteEscucha) await _escucharYResponder(ciclo, estadoEspera: EstadoConversacion.crisis);
      case TipoTurno.pregunta || TipoTurno.confirmacion || TipoTurno.aclaracion:
        if (voz.admiteEscucha) {
          await _escucharYResponder(ciclo);
        } else {
          _cambiar(EstadoConversacion.esperandoTexto);
        }
    }
  }

  Future<void> _escucharYResponder(int ciclo, {EstadoConversacion? estadoEspera}) async {
    _cambiar(estadoEspera ?? EstadoConversacion.escuchando);
    avatar.escuchar();
    final oido = await voz.escuchar();
    if (_obsoleto(ciclo)) return;

    if (oido == null || oido.trim().isEmpty) {
      _silencios++;
      avatar.detener();
      if (_silencios >= maxSilencios || estadoEspera == EstadoConversacion.crisis) {
        _cambiar(estadoEspera ?? EstadoConversacion.pausada);
        return;
      }
      await _correr(sesion.responder(''));
      return;
    }
    _silencios = 0;
    avatar.pensar();
    _historial.add(MensajeChat(deAvatar: false, texto: oido.trim()));
    await _correr(sesion.responder(oido));
  }

  Future<void> _guardar() async {
    _cambiar(EstadoConversacion.guardando);
    avatar.pensar();
    try {
      await guardar(sesion.filaSupabase());
      _error = null;
      avatar.cambiarEmocion(EmocionAvatar.alegre);
      avatar.detener();
      _cambiar(EstadoConversacion.terminada);
    } catch (e) {
      _error = e;
      avatar.detener();
      _cambiar(EstadoConversacion.error);
    }
  }

  /// Interrumpe lo que esté diciendo o escuchando e invalida ese ciclo.
  Future<void> _cortarEscucha() async {
    _ciclo++;
    if (_estado == EstadoConversacion.escuchando || _estado == EstadoConversacion.hablando) {
      await voz.detener();
    }
  }

  bool _obsoleto(int ciclo) => _cerrado || ciclo != _ciclo;

  void _cambiar(EstadoConversacion e) {
    if (_cerrado) return;
    _estado = e;
    notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    voz.detener();
    super.dispose();
  }
}
