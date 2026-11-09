import 'guion.dart';
import 'texto_es.dart';

/// Resultado de interpretar una respuesta.
enum MotivoExtraccion { ok, sinValor, ambiguo, fueraDeRango }

class Extraccion {
  const Extraccion({
    this.valor,
    this.confianza = 0,
    this.motivo = MotivoExtraccion.sinValor,
    this.candidatos = const [],
  });

  /// String (opción), double (número), int (escala) o bool (sí/no).
  final Object? valor;

  /// 0..1. Por debajo del umbral del guion, el avatar reconfirma.
  final double confianza;
  final MotivoExtraccion motivo;

  /// Opciones que coincidieron cuando la respuesta es ambigua.
  final List<String> candidatos;

  bool get ok => motivo == MotivoExtraccion.ok;
}

const _si = [
  'si', 'claro', 'obvio', 'afirmativo', 'correcto', 'exacto', 'asi es', 'efectivamente',
  'he tenido', 'tengo', 'tuve', 'sip', 'aja', 'por supuesto', 'de acuerdo', 'eso es', 'a veces',
];
const _no = ['no', 'nunca', 'jamas', 'ninguno', 'ninguna', 'para nada', 'nop', 'negativo', 'tampoco'];
const _duda = ['no se', 'no estoy seguro', 'no estoy segura', 'no recuerdo', 'no me acuerdo'];

/// Orden importa: se prueba de arriba abajo ("muy poco" antes que "poco").
const _cualitativos = [
  ('muchisimo', 10), ('demasiado', 10), ('extremo', 10), ('bastante', 7), ('mucho', 8),
  ('muy poco', 2), ('poquito', 2), ('poco', 3), ('nada', 1), ('regular', 5),
  ('mas o menos', 5), ('normal', 5), ('medio', 5),
];
const _diario = ['al dia', 'diario', 'diarias', 'diarios', 'por dia', 'cada dia', 'diariamente'];
const _semanal = ['a la semana', 'semanal', 'semanales', 'por semana', 'cada semana', 'semanalmente'];
const _cero = ['nada', 'ninguna', 'ninguno', 'no hago', 'no tengo', 'cero'];

int? _primera(String t, List<String> frases) {
  int? menor;
  for (final f in frases) {
    for (final p in posiciones(t, f)) {
      if (menor == null || p < menor) menor = p;
    }
  }
  return menor;
}

/// Interpreta [texto] (lo que reconoció el STT) para la [pregunta].
Extraccion extraer(String texto, PreguntaGuion pregunta) {
  final t = normalizar(texto);
  return switch (pregunta.tipo) {
    TipoPregunta.siNo => extraerSiNo(t),
    TipoPregunta.opcion => _extraerOpcion(t, pregunta),
    TipoPregunta.numero => _extraerNumero(t, pregunta),
    TipoPregunta.escala => _extraerEscala(t, pregunta),
    TipoPregunta.mensaje => const Extraccion(),
  };
}

/// Sí/no sobre texto YA normalizado. Si aparecen ambos, gana el primero
/// con confianza baja ("sí… bueno no" → reconfirma).
Extraccion extraerSiNo(String t) {
  if (_duda.any((d) => contiene(t, d))) return const Extraccion();
  final si = _primera(t, _si);
  final no = _primera(t, _no);
  if (si == null && no == null) return const Extraccion();
  if (no == null) return const Extraccion(valor: true, confianza: 0.95, motivo: MotivoExtraccion.ok);
  if (si == null) return const Extraccion(valor: false, confianza: 0.95, motivo: MotivoExtraccion.ok);
  return Extraccion(valor: si < no, confianza: 0.6, motivo: MotivoExtraccion.ok);
}

bool _negado(String t, int pos, String sinonimo) {
  if (sinonimo.startsWith('no ')) return false;
  final antes = palabras(t.substring(0, pos));
  final ultimas = antes.length > 2 ? antes.sublist(antes.length - 2) : antes;
  return ultimas.contains('no') || ultimas.contains('ni');
}

Extraccion _extraerOpcion(String t, PreguntaGuion p) {
  // Tramos (inicio, fin) de cada opción que aparece sin negación
  final tramos = <String, List<(int, int)>>{};
  for (final op in p.opciones) {
    for (final s in op.sinonimos) {
      for (final pos in posiciones(t, s)) {
        if (!_negado(t, pos, s)) {
          tramos.putIfAbsent(op.valor, () => []).add((pos, pos + s.length));
        }
      }
    }
  }
  // Una opción cuyos tramos caen todos dentro del tramo de OTRA opción no
  // cuenta ("no binario" contiene "binario").
  bool contenido(String v) => tramos[v]!.every((t1) => tramos.entries.any((e) =>
      e.key != v &&
      e.value.any((t2) => t2.$1 <= t1.$1 && t1.$2 <= t2.$2 && t2 != t1)));

  final validos = tramos.keys.where((v) => !contenido(v)).toList();
  if (validos.isEmpty) return const Extraccion();
  if (validos.length == 1) {
    return Extraccion(valor: validos.first, confianza: 0.9, motivo: MotivoExtraccion.ok);
  }
  return Extraccion(motivo: MotivoExtraccion.ambiguo, candidatos: validos);
}

/// (valor, confianza); valor null si no hay número o hay dos sin relación.
(double?, double) _valorNumerico(String t) {
  final ns = numeros(t);
  if (ns.isEmpty) {
    if (_cero.any((c) => contiene(t, c))) return (0.0, 0.7);
    return (null, 0.0);
  }
  if (ns.length >= 2) {
    final a = ns[0], b = ns[1];
    final p = palabras(t);
    final entre = p.sublist(a.fin, b.inicio).join(' ');
    final antes = p[a.inicio > 0 ? a.inicio - 1 : 0];
    if (const ['y', 'o', 'a', 'u', 'o sea'].contains(entre) || antes == 'entre') {
      // "seis o siete", "entre 6 y 7": el promedio, y se reconfirma
      return ((a.valor + b.valor) / 2, 0.6);
    }
    return (null, 0.0);
  }
  final n = ns.first;
  return (n.valor, n.dePalabras ? 0.9 : 0.95);
}

Extraccion _extraerNumero(String t, PreguntaGuion p) {
  var (valor, confianza) = _valorNumerico(t);
  if (valor == null) {
    return Extraccion(
        motivo: numeros(t).length >= 2 ? MotivoExtraccion.ambiguo : MotivoExtraccion.sinValor);
  }
  if (p.periodo == 'semana' && _diario.any((d) => contiene(t, d))) {
    valor = valor * p.diasPorSemana;
    if (confianza > 0.6) confianza = 0.6;
  } else if (p.periodo == 'dia' && _semanal.any((s) => contiene(t, s))) {
    valor = valor / 7;
    if (confianza > 0.6) confianza = 0.6;
  }
  valor = redondearDecima(valor);
  if (valor < p.min! || valor > p.max!) {
    return Extraccion(valor: valor, confianza: confianza, motivo: MotivoExtraccion.fueraDeRango);
  }
  return Extraccion(valor: valor, confianza: confianza, motivo: MotivoExtraccion.ok);
}

Extraccion _extraerEscala(String t, PreguntaGuion p) {
  final ns = numeros(t);
  if (ns.isNotEmpty) {
    var (valor, confianza) = _valorNumerico(t);
    if (valor == null) return const Extraccion(motivo: MotivoExtraccion.ambiguo);
    final entero = (valor + 0.5).floor(); // 6.5 → 7
    if (valor != entero && confianza > 0.6) confianza = 0.6;
    if (entero < p.min! || entero > p.max!) {
      return Extraccion(valor: entero, confianza: confianza, motivo: MotivoExtraccion.fueraDeRango);
    }
    return Extraccion(valor: entero, confianza: confianza, motivo: MotivoExtraccion.ok);
  }
  for (final (palabra, valor) in _cualitativos) {
    if (contiene(t, palabra)) {
      return Extraccion(valor: valor, confianza: 0.6, motivo: MotivoExtraccion.ok);
    }
  }
  return const Extraccion();
}
