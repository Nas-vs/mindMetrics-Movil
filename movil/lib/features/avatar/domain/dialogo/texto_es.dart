// Utilidades de texto en español para entender respuestas habladas.
//
// Todo opera sobre texto NORMALIZADO: minúsculas, sin tildes, sin signos,
// con la coma decimal convertida a punto ("6,5" → "6.5").

const _tildes = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

final _comaDecimal = RegExp(r'(\d),(\d)');
final _noPermitidos = RegExp(r'[^a-z0-9.\s]');
final _puntoSuelto = RegExp(r'(?<!\d)\.|\.(?!\d)');
final _espacios = RegExp(r'\s+');
final _cifra = RegExp(r'^\d+(\.\d+)?$');

String normalizar(String texto) {
  final b = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    b.write(_tildes[c] ?? c);
  }
  return b
      .toString()
      .replaceAllMapped(_comaDecimal, (m) => '${m[1]}.${m[2]}')
      .replaceAll(_noPermitidos, ' ')
      .replaceAll(_puntoSuelto, ' ')
      .replaceAll(_espacios, ' ')
      .trim();
}

RegExp _frase(String frase) =>
    RegExp('(?<![a-z0-9])${RegExp.escape(frase)}(?![a-z0-9])');

/// La frase aparece como palabras completas ("si" no aparece en "siempre").
bool contiene(String texto, String frase) => _frase(frase).hasMatch(texto);

/// Posiciones (índice de carácter) donde aparece la frase.
List<int> posiciones(String texto, String frase) =>
    _frase(frase).allMatches(texto).map((m) => m.start).toList();

List<String> palabras(String texto) =>
    texto.split(' ').where((p) => p.isNotEmpty).toList();

// ---------------------------------------------------------------- números

const _unidades = {
  'cero': 0, 'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4,
  'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
};
const _especiales = {
  'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14,
  'quince': 15, 'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18,
  'diecinueve': 19, 'veinte': 20, 'veintiun': 21, 'veintiuno': 21,
  'veintiuna': 21, 'veintidos': 22, 'veintitres': 23, 'veinticuatro': 24,
  'veinticinco': 25, 'veintiseis': 26, 'veintisiete': 27, 'veintiocho': 28,
  'veintinueve': 29,
};
const _decenas = {
  'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60,
  'setenta': 70, 'ochenta': 80, 'noventa': 90,
};

/// Un número encontrado en el texto, con su tramo en palabras [inicio, fin).
class NumeroEnTexto {
  const NumeroEnTexto(this.valor, this.inicio, this.fin, {required this.dePalabras});
  final double valor;
  final int inicio;
  final int fin;

  /// `true` si se dijo en palabras ("seis") y no en cifras ("6").
  final bool dePalabras;
}

bool _esNumero(String w) =>
    _cifra.hasMatch(w) ||
    _unidades.containsKey(w) ||
    _especiales.containsKey(w) ||
    _decenas.containsKey(w) ||
    w == 'cien' ||
    w == 'ciento';

/// Lee un número que empieza en la palabra [i]: (valor, siguiente, dePalabras).
(double, int, bool)? _numeroEn(List<String> p, int i) {
  final w = p[i];
  if (_cifra.hasMatch(w)) return (double.parse(w), i + 1, false);
  if (w == 'cien' || w == 'ciento') {
    final j = i + 1;
    if (w == 'ciento' && j < p.length) {
      final resto = _numeroEn(p, j);
      if (resto != null && resto.$1 < 100) return (100.0 + resto.$1, resto.$2, true);
    }
    return (100.0, j, true);
  }
  final decena = _decenas[w];
  if (decena != null) {
    final j = i + 1;
    if (j + 1 < p.length && p[j] == 'y' && _unidades.containsKey(p[j + 1]) && p[j + 1] != 'cero') {
      return (decena.toDouble() + _unidades[p[j + 1]]!.toDouble(), j + 2, true);
    }
    return (decena.toDouble(), j, true);
  }
  final especial = _especiales[w];
  if (especial != null) return (especial.toDouble(), i + 1, true);
  final unidad = _unidades[w];
  if (unidad != null) {
    // "un ocho", "una seis": el artículo no es un número
    if ((w == 'un' || w == 'una') && i + 1 < p.length && _esNumero(p[i + 1])) return null;
    return (unidad.toDouble(), i + 1, true);
  }
  return null;
}

/// Todos los números del texto normalizado, incluidos "y media", "y cuarto",
/// "media hora" y "hora y media".
List<NumeroEnTexto> numeros(String texto) {
  final p = palabras(texto);
  final out = <NumeroEnTexto>[];
  var i = 0;
  while (i < p.length) {
    if (p[i] == 'media' && i + 1 < p.length && p[i + 1].startsWith('hora') && !(i > 0 && p[i - 1] == 'y')) {
      out.add(NumeroEnTexto(0.5, i, i + 2, dePalabras: true));
      i += 2;
      continue;
    }
    if (p[i] == 'hora' && i + 2 < p.length && p[i + 1] == 'y' && p[i + 2] == 'media' &&
        !out.any((n) => n.inicio <= i - 1 && i - 1 < n.fin)) {
      out.add(NumeroEnTexto(1.5, i, i + 3, dePalabras: true));
      i += 3;
      continue;
    }
    final r = _numeroEn(p, i);
    if (r == null) {
      i += 1;
      continue;
    }
    var (valor, j, dePalabras) = r;
    final k = (j < p.length && p[j].startsWith('hora')) ? j + 1 : j;
    if (k + 1 < p.length && p[k] == 'y' && (p[k + 1] == 'media' || p[k + 1] == 'medio')) {
      valor += 0.5;
      j = k + 2;
    } else if (k + 1 < p.length && p[k] == 'y' && p[k + 1] == 'cuarto') {
      valor += 0.25;
      j = k + 2;
    }
    out.add(NumeroEnTexto(valor, i, j, dePalabras: dePalabras));
    i = j;
  }
  return out;
}

/// Redondeo a una décima con "mitad al par", igual que round() de Python.
double redondearDecima(double v) {
  final x = v * 10;
  final piso = x.floorToDouble();
  if (x - piso == 0.5) return (piso % 2 == 0 ? piso : piso + 1) / 10;
  return x.roundToDouble() / 10;
}
