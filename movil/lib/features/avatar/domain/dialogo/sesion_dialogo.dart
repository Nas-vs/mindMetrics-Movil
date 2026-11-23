import '../estado_avatar.dart';
import 'extractor.dart';
import 'guion.dart';
import 'texto_es.dart';

/// Qué responde el avatar en cada turno.
enum TipoTurno {
  /// Hace una pregunta (o la siguiente, tras guardar la anterior).
  pregunta,

  /// "Entendí X. ¿Es correcto?"
  confirmacion,

  /// No entendió, fuera de rango o pide corregir; puede traer opciones.
  aclaracion,

  /// Detectó una frase de riesgo: muestra ayuda y se detiene.
  crisis,

  /// Terminó: las respuestas están listas para guardar.
  fin,

  /// El usuario pidió el formulario clásico.
  formulario,
}

class OpcionTurno {
  const OpcionTurno(this.valor, this.etiqueta);
  final Object valor;
  final String etiqueta;
}

class Turno {
  const Turno({
    required this.tipo,
    required this.texto,
    required this.emocion,
    this.campo,
    this.opciones = const [],
    this.progreso = 0,
  });

  final TipoTurno tipo;

  /// Lo que dice el avatar (va al TTS y al historial).
  final String texto;
  final EmocionAvatar emocion;

  /// Pregunta a la que se refiere el turno.
  final String? campo;

  /// Botones para tocar en vez de hablar (respaldo).
  final List<OpcionTurno> opciones;

  /// 0..1: preguntas respondidas / total.
  final double progreso;

  @override
  String toString() => 'Turno($tipo, $campo, "$texto")';
}

/// Rellena `{mascota}` y `{apodo}` en lo que dice el avatar.
///
/// Sin apodo (sesión sin `app_metadata.nickname`, demo, pruebas) se quita el
/// marcador con su coma: "Hola, {apodo}." → "Hola." En el guion, escribir
/// `{apodo}` después de una coma o al inicio seguido de coma.
String personalizar(String texto, {required String mascota, String? apodo}) {
  var t = texto.replaceAll('{mascota}', mascota);
  final a = apodo?.trim() ?? '';
  if (a.isNotEmpty) return t.replaceAll('{apodo}', a);
  t = t.replaceAll(RegExp(r',\s*\{apodo\}'), '');
  t = t.replaceAll(RegExp(r'\{apodo\},?\s*'), '');
  return t;
}

enum _Estado { inicio, respuesta, confirmacion, crisis, fin, formulario }

/// Motor de diálogo: recorre el guion, interpreta cada respuesta, reconfirma
/// cuando no está seguro y arma la fila de `evaluaciones_iniciales`.
///
/// Es lógica pura (sin voz ni red): la usa `ConversacionControlador`.
class SesionDialogo {
  SesionDialogo(this.guion, {this.mascota = 'Nimbus', this.apodo})
      : _total = guion.preguntasConRespuesta.length;

  final Guion guion;
  final String mascota;

  /// Nickname del registro (RF-07). `null` → saludo sin nombre.
  final String? apodo;
  final int _total;

  int _i = 0;
  _Estado _estado = _Estado.inicio;
  int _intentos = 0;
  Object? _pendiente;
  final Map<String, Object> _respuestas = {};
  bool _huboCrisis = false;

  Map<String, Object> get respuestas => Map.unmodifiable(_respuestas);
  bool get terminada => _estado == _Estado.fin;
  bool get huboCrisis => _huboCrisis;
  bool get enCrisis => _estado == _Estado.crisis;

  /// `true` si se puede llamar a [responder] (hay pregunta, confirmación o
  /// crisis abierta).
  bool get esperaRespuesta =>
      _estado == _Estado.respuesta || _estado == _Estado.confirmacion || _estado == _Estado.crisis;

  PreguntaGuion get _actual => guion.preguntas[_i];
  double get _progreso => _respuestas.length / _total;

  // ------------------------------------------------------------- API

  Turno iniciar() {
    final b = guion.bienvenida;
    final t = _preguntar(b.texto);
    return _personalizado(
      Turno(tipo: t.tipo, texto: t.texto, emocion: b.emocion, campo: t.campo, progreso: t.progreso),
    );
  }

  /// Procesa lo que dijo (o escribió) el usuario. Un texto vacío cuenta como
  /// "no se entendió" (silencio del micrófono).
  Turno responder(String texto) => _personalizado(_responder(texto));

  /// El usuario tocó una opción en pantalla: se guarda sin reconfirmar.
  Turno elegir(Object valor) => _personalizado(_elegir(valor));

  Turno _personalizado(Turno t) {
    final texto = personalizar(t.texto, mascota: mascota, apodo: apodo);
    if (texto == t.texto) return t;
    return Turno(
      tipo: t.tipo,
      texto: texto,
      emocion: t.emocion,
      campo: t.campo,
      opciones: t.opciones,
      progreso: t.progreso,
    );
  }

  Turno _responder(String texto) {
    if (_estado == _Estado.fin || _estado == _Estado.formulario || _estado == _Estado.inicio) {
      throw StateError('La sesión no está esperando respuesta ($_estado).');
    }
    final t = normalizar(texto);

    if (guion.crisis.frases.any((f) => contiene(t, f))) {
      _huboCrisis = true;
      _estado = _Estado.crisis;
      return _turnoCrisis();
    }
    if (_estado == _Estado.crisis) {
      if (_esComando(t, guion.crisis.continuar)) {
        _pendiente = null;
        _estado = _Estado.respuesta;
        return Turno(
          tipo: TipoTurno.pregunta,
          texto: guion.mensaje('continuar_tras_crisis', {'pregunta': _actual.texto}),
          emocion: EmocionAvatar.empatico,
          campo: _actual.campo,
          progreso: _progreso,
        );
      }
      return _turnoCrisis();
    }
    if (_esComando(t, guion.comandos['formulario'] ?? const [])) {
      _estado = _Estado.formulario;
      return Turno(
        tipo: TipoTurno.formulario,
        texto: guion.mensaje('formulario'),
        emocion: EmocionAvatar.neutral,
        progreso: _progreso,
      );
    }
    if (_esComando(t, guion.comandos['repetir'] ?? const [])) {
      if (_estado == _Estado.confirmacion) return _turnoConfirmar();
      return Turno(
        tipo: TipoTurno.pregunta,
        texto: _actual.texto,
        emocion: _actual.emocion,
        campo: _actual.campo,
        progreso: _progreso,
      );
    }

    final p = _actual;
    if (_estado == _Estado.confirmacion) return _responderConfirmacion(t, texto, p);
    return _evaluar(extraer(texto, p), p);
  }

  Turno _elegir(Object valor) {
    if (_estado != _Estado.respuesta && _estado != _Estado.confirmacion) {
      throw StateError('No hay una pregunta abierta ($_estado).');
    }
    final validas = _opcionesDe(_actual);
    if (validas.isNotEmpty && !validas.any((o) => o.valor == valor)) {
      throw ArgumentError.value(valor, 'valor', 'no es una opción de ${_actual.campo}');
    }
    return _guardarYSeguir(valor);
  }

  /// Fila lista para `insert` en `evaluaciones_iniciales` (canal = voz).
  Map<String, Object> filaSupabase() {
    if (!terminada) throw StateError('La sesión no ha terminado.');
    return {'canal': 'voz', ..._respuestas};
  }

  // ------------------------------------------------------------- internos

  Turno _responderConfirmacion(String t, String original, PreguntaGuion p) {
    final sn = extraerSiNo(t);
    final nuevo = extraer(original, p);
    final traeOtroValor = p.tipo != TipoPregunta.siNo && nuevo.ok && nuevo.valor != _pendiente;

    if (sn.ok && sn.valor == true && !traeOtroValor) {
      return _guardarYSeguir(_pendiente!, guion.mensaje('confirmado'));
    }
    if (sn.ok && sn.valor == false) {
      // "no, siete": trae el valor correcto → se toma sin volver a preguntar
      if (traeOtroValor) return _guardarYSeguir(nuevo.valor!, guion.mensaje('confirmado'));
      _pendiente = null;
      _estado = _Estado.respuesta;
      return Turno(
        tipo: TipoTurno.aclaracion,
        texto: '${guion.mensaje('corregir')} ${p.texto}',
        emocion: p.emocion,
        campo: p.campo,
        progreso: _progreso,
      );
    }
    if (nuevo.ok && p.tipo != TipoPregunta.siNo) return _evaluar(nuevo, p);
    return _turnoConfirmar();
  }

  Turno _evaluar(Extraccion ex, PreguntaGuion p) {
    if (ex.ok) {
      if (ex.confianza >= guion.umbralConfirmacion) return _guardarYSeguir(ex.valor!);
      _pendiente = ex.valor;
      _estado = _Estado.confirmacion;
      return _turnoConfirmar();
    }
    _intentos++;
    final opciones = _opcionesDe(p);
    if (_intentos >= guion.intentosAntesDeOpciones && opciones.isNotEmpty) {
      return Turno(
        tipo: TipoTurno.aclaracion,
        texto: guion.mensaje('usar_opciones', {'pregunta': p.texto}),
        emocion: p.emocion,
        campo: p.campo,
        opciones: opciones,
        progreso: _progreso,
      );
    }
    final texto = ex.motivo == MotivoExtraccion.fueraDeRango
        ? guion.mensaje('fuera_de_rango', {'min': p.min!, 'max': p.max!, 'pregunta': p.texto})
        : guion.mensaje('no_entendi', {'pregunta': p.texto});
    return Turno(
      tipo: TipoTurno.aclaracion,
      texto: texto,
      emocion: p.emocion,
      campo: p.campo,
      progreso: _progreso,
    );
  }

  Turno _guardarYSeguir(Object valor, [String prefijo = '']) {
    _respuestas[_actual.campo] = valor;
    _i++;
    _intentos = 0;
    _pendiente = null;
    if (_i >= guion.preguntas.length) {
      _estado = _Estado.fin;
      final d = guion.despedida;
      return Turno(
        tipo: TipoTurno.fin,
        texto: [prefijo, d.texto].where((s) => s.isNotEmpty).join(' '),
        emocion: d.emocion,
        progreso: 1,
      );
    }
    return _preguntar(prefijo);
  }

  /// Dice los mensajes de transición pendientes y la siguiente pregunta.
  Turno _preguntar([String prefijo = '']) {
    final textos = [if (prefijo.isNotEmpty) prefijo];
    while (_actual.tipo == TipoPregunta.mensaje) {
      textos.add(_actual.texto);
      _i++;
    }
    final p = _actual;
    textos.add(p.texto);
    _estado = _Estado.respuesta;
    return Turno(
      tipo: TipoTurno.pregunta,
      texto: textos.join(' '),
      emocion: p.emocion,
      campo: p.campo,
      progreso: _progreso,
    );
  }

  Turno _turnoConfirmar() {
    final p = _actual;
    return Turno(
      tipo: TipoTurno.confirmacion,
      texto: guion.mensaje('confirmar', {'respuesta': _formatear(_pendiente!, p)}),
      emocion: p.emocion,
      campo: p.campo,
      opciones: const [OpcionTurno(true, 'Sí'), OpcionTurno(false, 'No')],
      progreso: _progreso,
    );
  }

  Turno _turnoCrisis() => Turno(
        tipo: TipoTurno.crisis,
        texto: guion.crisis.texto,
        emocion: guion.crisis.emocion,
        progreso: _progreso,
      );

  List<OpcionTurno> _opcionesDe(PreguntaGuion p) => switch (p.tipo) {
        TipoPregunta.opcion => [for (final o in p.opciones) OpcionTurno(o.valor, o.etiqueta)],
        TipoPregunta.siNo => const [OpcionTurno(true, 'Sí'), OpcionTurno(false, 'No')],
        TipoPregunta.escala => [
            for (var n = p.min!.toInt(); n <= p.max!.toInt(); n++) OpcionTurno(n, '$n'),
          ],
        _ => const [],
      };

  static bool _esComando(String t, List<String> frases) {
    final n = palabras(t).length;
    return frases.any((f) => contiene(t, f) && n <= palabras(f).length + 2);
  }

  static String _formatear(Object valor, PreguntaGuion p) => switch (p.tipo) {
        TipoPregunta.numero => '${_numero(valor as num)} ${p.unidad}',
        TipoPregunta.escala => '$valor de 10',
        TipoPregunta.siNo => valor == true ? 'que sí' : 'que no',
        _ => '«${p.opciones.firstWhere((o) => o.valor == valor).etiqueta}»',
      };

  static String _numero(num v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');
}
