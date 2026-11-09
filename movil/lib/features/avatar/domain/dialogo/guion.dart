import '../estado_avatar.dart';
import 'texto_es.dart';

/// Guion de la conversación, cargado desde `assets/guiones/*.json`.
///
/// El guion es DATO: cambiar preguntas, sinónimos o mensajes no requiere
/// tocar código. Los sinónimos se normalizan al cargar (se pueden escribir
/// con tildes).
enum TipoPregunta {
  opcion,
  numero,
  escala,
  siNo,

  /// Solo se dice; no espera respuesta (ej. una transición).
  mensaje;

  static TipoPregunta deJson(String t) => switch (t) {
        'opcion' => opcion,
        'numero' => numero,
        'escala' => escala,
        'si_no' => siNo,
        'mensaje' => mensaje,
        _ => throw FormatException('tipo de pregunta desconocido: $t'),
      };
}

EmocionAvatar _emocion(Object? e) =>
    EmocionAvatar.values.byName((e as String?) ?? 'neutral');

class OpcionGuion {
  OpcionGuion({required this.valor, required this.etiqueta, required List<String> sinonimos})
      : sinonimos = sinonimos.map(normalizar).toList();

  factory OpcionGuion.deJson(Map<String, dynamic> j) => OpcionGuion(
        valor: j['valor'] as String,
        etiqueta: j['etiqueta'] as String,
        sinonimos: (j['sinonimos'] as List).cast<String>(),
      );

  /// Valor que se guarda en la base (vocabulario del motor).
  final String valor;
  final String etiqueta;
  final List<String> sinonimos;
}

class PreguntaGuion {
  PreguntaGuion({
    required this.campo,
    required this.tipo,
    required this.texto,
    this.emocion = EmocionAvatar.neutral,
    this.min,
    this.max,
    this.periodo,
    this.diasPorSemana = 7,
    this.unidad = '',
    this.opciones = const [],
  });

  factory PreguntaGuion.deJson(Map<String, dynamic> j) => PreguntaGuion(
        campo: j['campo'] as String,
        tipo: TipoPregunta.deJson(j['tipo'] as String),
        texto: j['texto'] as String,
        emocion: _emocion(j['emocion']),
        min: j['min'] as num?,
        max: j['max'] as num?,
        periodo: j['periodo'] as String?,
        diasPorSemana: (j['dias_por_semana'] as num?)?.toInt() ?? 7,
        unidad: (j['unidad'] as String?) ?? '',
        opciones: [
          for (final o in (j['opciones'] as List?) ?? const []) OpcionGuion.deJson(o as Map<String, dynamic>),
        ],
      );

  /// Columna de `evaluaciones_iniciales`. Las que empiezan por "_" no se guardan.
  final String campo;
  final TipoPregunta tipo;
  final String texto;
  final EmocionAvatar emocion;
  final num? min;
  final num? max;

  /// 'dia' o 'semana': en qué unidad espera la base el valor.
  final String? periodo;

  /// Para pasar "8 horas al día" a horas por semana.
  final int diasPorSemana;
  final String unidad;
  final List<OpcionGuion> opciones;
}

class TextoConEmocion {
  const TextoConEmocion(this.texto, this.emocion);

  factory TextoConEmocion.deJson(Map<String, dynamic> j) =>
      TextoConEmocion(j['texto'] as String, _emocion(j['emocion']));

  final String texto;
  final EmocionAvatar emocion;
}

class LineaAyuda {
  const LineaAyuda({required this.nombre, required this.numero, required this.horario});

  factory LineaAyuda.deJson(Map<String, dynamic> j) => LineaAyuda(
        nombre: j['nombre'] as String,
        numero: j['numero'] as String,
        horario: j['horario'] as String,
      );

  final String nombre;
  final String numero;
  final String horario;
}

class CrisisGuion {
  CrisisGuion({
    required List<String> frases,
    required this.texto,
    required this.emocion,
    required List<String> continuar,
    required this.lineas,
  })  : frases = frases.map(normalizar).toList(),
        continuar = continuar.map(normalizar).toList();

  factory CrisisGuion.deJson(Map<String, dynamic> j) => CrisisGuion(
        frases: (j['frases'] as List).cast<String>(),
        texto: j['texto'] as String,
        emocion: _emocion(j['emocion']),
        continuar: (j['continuar'] as List).cast<String>(),
        lineas: [for (final l in j['lineas'] as List) LineaAyuda.deJson(l as Map<String, dynamic>)],
      );

  final List<String> frases;
  final String texto;
  final EmocionAvatar emocion;
  final List<String> continuar;
  final List<LineaAyuda> lineas;
}

class Guion {
  Guion({
    required this.id,
    required this.version,
    required this.umbralConfirmacion,
    required this.intentosAntesDeOpciones,
    required this.bienvenida,
    required this.despedida,
    required this.mensajes,
    required this.crisis,
    required this.comandos,
    required this.preguntas,
  });

  factory Guion.deJson(Map<String, dynamic> j) => Guion(
        id: j['id'] as String,
        version: j['version'] as String,
        umbralConfirmacion: (j['umbral_confirmacion'] as num).toDouble(),
        intentosAntesDeOpciones: (j['intentos_antes_de_opciones'] as num).toInt(),
        bienvenida: TextoConEmocion.deJson(j['bienvenida'] as Map<String, dynamic>),
        despedida: TextoConEmocion.deJson(j['despedida'] as Map<String, dynamic>),
        mensajes: (j['mensajes'] as Map).cast<String, String>(),
        crisis: CrisisGuion.deJson(j['crisis'] as Map<String, dynamic>),
        comandos: {
          for (final e in (j['comandos'] as Map<String, dynamic>).entries)
            e.key: (e.value as List).cast<String>().map(normalizar).toList(),
        },
        preguntas: [
          for (final p in j['preguntas'] as List) PreguntaGuion.deJson(p as Map<String, dynamic>),
        ],
      );

  final String id;
  final String version;
  final double umbralConfirmacion;
  final int intentosAntesDeOpciones;
  final TextoConEmocion bienvenida;
  final TextoConEmocion despedida;
  final Map<String, String> mensajes;
  final CrisisGuion crisis;
  final Map<String, List<String>> comandos;
  final List<PreguntaGuion> preguntas;

  /// Preguntas que esperan respuesta (sin los mensajes de transición).
  Iterable<PreguntaGuion> get preguntasConRespuesta =>
      preguntas.where((p) => p.tipo != TipoPregunta.mensaje);

  /// Rellena "{clave}" con los valores dados.
  String mensaje(String clave, [Map<String, Object> valores = const {}]) {
    var t = mensajes[clave] ?? '';
    valores.forEach((k, v) => t = t.replaceAll('{$k}', '$v'));
    return t;
  }
}
