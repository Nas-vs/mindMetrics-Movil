/// RF-08: modelo del registro de ánimo del día.
///
/// Refleja la respuesta de la RPC `guardar_registro_animo` y la fila de
/// `registros_animo` con sus tablas puente (`registro_emociones`,
/// `registro_factores`).
class RegistroAnimo {
  const RegistroAnimo({
    required this.id,
    required this.fecha,
    required this.nivel,
    this.emociones = const {},
    this.factores = const {},
    this.nota,
    required this.actualizadoEnCliente,
  });

  /// UUID generado en el celular: permite guardar sin conexión y que la RPC
  /// reconozca el mismo registro al sincronizar (idempotente).
  final String id;

  /// Día LOCAL del celular en formato AAAA-MM-DD (igual que RF-22).
  final String fecha;

  /// 1 = muy mal … 5 = muy bien (CA-2: 5 emojis).
  final int nivel;
  final Set<int> emociones;
  final Set<int> factores;
  final String? nota;

  /// Marca de tiempo del cliente: la RPC aplica "gana el más reciente".
  final DateTime actualizadoEnCliente;

  RegistroAnimo copyWith({
    int? nivel,
    Set<int>? emociones,
    Set<int>? factores,
    String? nota,
    DateTime? actualizadoEnCliente,
  }) =>
      RegistroAnimo(
        id: id,
        fecha: fecha,
        nivel: nivel ?? this.nivel,
        emociones: emociones ?? this.emociones,
        factores: factores ?? this.factores,
        nota: nota ?? this.nota,
        actualizadoEnCliente: actualizadoEnCliente ?? this.actualizadoEnCliente,
      );

  Map<String, dynamic> aJson() => {
        'id': id,
        'fecha': fecha,
        'nivel': nivel,
        'emociones': emociones.toList()..sort(),
        'factores': factores.toList()..sort(),
        'nota': nota,
        'actualizado_en_cliente': actualizadoEnCliente.toUtc().toIso8601String(),
      };

  /// Acepta tanto el JSON de la RPC (`emociones: [1,2]`) como la fila con
  /// tablas anidadas (`registro_emociones: [{emocion_id: 1}]`).
  factory RegistroAnimo.desdeJson(Map<String, dynamic> j) {
    Set<int> ids(dynamic lista, String campo) => {
          for (final e in (lista as List? ?? const []))
            e is Map ? (e[campo] as num).toInt() : (e as num).toInt(),
        };
    return RegistroAnimo(
      id: j['id'] as String,
      fecha: j['fecha'] as String,
      nivel: (j['nivel'] as num).toInt(),
      emociones: ids(j['emociones'] ?? j['registro_emociones'], 'emocion_id'),
      factores: ids(j['factores'] ?? j['registro_factores'], 'factor_id'),
      nota: j['nota'] as String?,
      actualizadoEnCliente:
          DateTime.parse(j['actualizado_en_cliente'] as String),
    );
  }
}

/// Elemento de los catálogos `emociones` y `factores` (chips de CA-4).
class OpcionCatalogo {
  const OpcionCatalogo({required this.id, required this.nombre});
  final int id;
  final String nombre;
}

/// CA-2: los 5 niveles con su emoji y su etiqueta. Mismo set de emojis que
/// la bienvenida (RF-01) para que la app sea coherente.
class NivelAnimo {
  const NivelAnimo(this.valor, this.emoji, this.etiqueta);
  final int valor;
  final String emoji;
  final String etiqueta;

  static const todos = [
    NivelAnimo(1, '😞', 'Muy mal'),
    NivelAnimo(2, '🙁', 'Mal'),
    NivelAnimo(3, '😐', 'Normal'),
    NivelAnimo(4, '🙂', 'Bien'),
    NivelAnimo(5, '😄', 'Muy bien'),
  ];

  static NivelAnimo de(int valor) => todos[valor - 1];
}

/// Día local AAAA-MM-DD. Mismo formato que `RegistroHoySupabase` (RF-22).
String fechaLocal(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
