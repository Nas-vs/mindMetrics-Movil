import '../../../../animo/domain/registro_animo.dart';

/// Estado de la evaluación inicial (motor de riesgo) visto desde el Inicio.
enum EstadoEvaluacion {
  /// Sin red o error al consultar: no se afirma nada.
  desconocido,

  /// No existe fila en `evaluaciones_iniciales`.
  pendiente,

  /// La evaluación existe pero el motor aún no escribió en `niveles_riesgo`.
  calculando,

  /// Hay nivel en `nivel_riesgo_actual`.
  listo,
}

/// Último resultado del motor (vista `nivel_riesgo_actual`).
class ResultadoEvaluacion {
  const ResultadoEvaluacion({
    required this.estado,
    this.nivel,
    this.origen,
    this.calculadoEn,
  });

  const ResultadoEvaluacion.desconocido() : this(estado: EstadoEvaluacion.desconocido);
  const ResultadoEvaluacion.pendiente() : this(estado: EstadoEvaluacion.pendiente);
  const ResultadoEvaluacion.calculando() : this(estado: EstadoEvaluacion.calculando);

  final EstadoEvaluacion estado;

  /// 1 = muy bajo … 5 = crítico (CHECK de `niveles_riesgo.nivel`).
  final int? nivel;

  /// 'evaluacion_inicial' | 'encuesta_diaria'
  final String? origen;
  final DateTime? calculadoEn;

  /// Mismas etiquetas que `niveles_riesgo.etiqueta` y la web
  /// (muy_bajo, bajo, moderado, alto, critico).
  static const _etiquetas = ['Muy bajo', 'Bajo', 'Moderado', 'Alto', 'Crítico'];

  String get textoCorto => switch (estado) {
        EstadoEvaluacion.listo => 'Riesgo ${_etiquetas[nivel! - 1].toLowerCase()}',
        EstadoEvaluacion.calculando => 'En cálculo…',
        EstadoEvaluacion.pendiente => 'Pendiente',
        EstadoEvaluacion.desconocido => 'Sin datos',
      };

  String? get etiqueta => nivel == null ? null : _etiquetas[nivel! - 1];

  factory ResultadoEvaluacion.desdeJson(Map<String, dynamic> j) => ResultadoEvaluacion(
        estado: EstadoEvaluacion.listo,
        nivel: (j['nivel'] as num).toInt(),
        origen: j['origen'] as String?,
        calculadoEn: j['calculado_en'] == null
            ? null
            : DateTime.parse(j['calculado_en'] as String).toLocal(),
      );
}

/// Un día de la tira semanal del Inicio.
class DiaSemana {
  const DiaSemana({required this.fecha, this.nivel});
  final DateTime fecha;

  /// Nivel de ánimo 1–5 de `registros_animo`; null = sin registro.
  final int? nivel;
}

/// Métricas del panel de Inicio.
class HomeSummaryModel {
  const HomeSummaryModel({
    required this.username,
    this.animoHoy,
    this.evaluacion = const ResultadoEvaluacion.desconocido(),
    this.racha = 0,
    this.semana = const [],
  });

  final String username;

  /// Nivel 1–5 registrado hoy (RF-08); null = aún no registra.
  final int? animoHoy;
  final ResultadoEvaluacion evaluacion;

  /// Días seguidos con registro de ánimo hasta hoy (o ayer, si hoy aún no
  /// registra: la racha no se rompe hasta que termina el día).
  final int racha;

  /// Lunes a domingo de la última semana con al menos un registro.
  final List<DiaSemana> semana;

  factory HomeSummaryModel.initial() => const HomeSummaryModel(username: 'Usuario');

  NivelAnimo? get nivelHoy => animoHoy == null ? null : NivelAnimo.de(animoHoy!);

  bool get semanaTieneRegistros => semana.any((d) => d.nivel != null);

  // -------------------------------------------------------------------------
  // Cálculos puros (se prueban sin Supabase)
  // -------------------------------------------------------------------------

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [niveles]: fecha local 'AAAA-MM-DD' → nivel.
  static int calcularRacha(Map<String, int> niveles, DateTime hoy) {
    var dia = _soloFecha(hoy);
    if (!niveles.containsKey(fechaLocal(dia))) {
      dia = DateTime(dia.year, dia.month, dia.day - 1);
    }
    var racha = 0;
    while (niveles.containsKey(fechaLocal(dia))) {
      racha++;
      dia = DateTime(dia.year, dia.month, dia.day - 1);
    }
    return racha;
  }

  /// Semana (lunes–domingo) que contiene el registro más reciente. Sin
  /// registros, la semana actual vacía.
  static List<DiaSemana> ultimaSemanaRegistrada(Map<String, int> niveles, DateTime hoy) {
    var referencia = _soloFecha(hoy);
    if (niveles.isNotEmpty) {
      final ultima = niveles.keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
      referencia = DateTime.parse(ultima);
    }
    // DateTime(año, mes, día ± n) normaliza el desborde de mes y evita los
    // saltos de horario de verano que tendría sumar Duration(days: n).
    final lunes = DateTime(referencia.year, referencia.month,
        referencia.day - (referencia.weekday - DateTime.monday));
    return [
      for (var i = 0; i < 7; i++)
        () {
          final f = DateTime(lunes.year, lunes.month, lunes.day + i);
          return DiaSemana(fecha: f, nivel: niveles[fechaLocal(f)]);
        }(),
    ];
  }

  static const _mesesCortos = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  /// "Esta semana" o "Semana del 16 al 22 nov" / "Semana del 30 nov al 6 dic".
  static String tituloSemana(List<DiaSemana> semana, DateTime hoy) {
    if (semana.isEmpty) return 'Última semana';
    final ini = semana.first.fecha;
    final fin = semana.last.fecha;
    final h = _soloFecha(hoy);
    if (!h.isBefore(ini) && !h.isAfter(fin)) return 'Esta semana';
    final mesIni = _mesesCortos[ini.month - 1];
    final mesFin = _mesesCortos[fin.month - 1];
    return ini.month == fin.month
        ? 'Semana del ${ini.day} al ${fin.day} $mesFin'
        : 'Semana del ${ini.day} $mesIni al ${fin.day} $mesFin';
  }
}
