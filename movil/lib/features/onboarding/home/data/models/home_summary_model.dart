/// Modelo de datos para las métricas del Home de MindMetrics.
class HomeSummaryModel {
  final String username;
  final String estadoHoy;
  final String registroEstimado;
  final String rachaDias;
  final String rachaTexto;

  const HomeSummaryModel({
    required this.username,
    required this.estadoHoy,
    required this.registroEstimado,
    required this.rachaDias,
    required this.rachaTexto,
  });

  /// Factory con valores predeterminados basados en el diseño.
  factory HomeSummaryModel.initial() {
    return const HomeSummaryModel(
      username: 'Usuario',
      estadoHoy: 'VARIABLE',
      registroEstimado: 'VARIABLE',
      rachaDias: '##',
      rachaTexto: 'VARIABLE DÍAS',
    );
  }

  HomeSummaryModel copyWith({
    String? username,
    String? estadoHoy,
    String? registroEstimado,
    String? rachaDias,
    String? rachaTexto,
  }) {
    return HomeSummaryModel(
      username: username ?? this.username,
      estadoHoy: estadoHoy ?? this.estadoHoy,
      registroEstimado: registroEstimado ?? this.registroEstimado,
      rachaDias: rachaDias ?? this.rachaDias,
      rachaTexto: rachaTexto ?? this.rachaTexto,
    );
  }
}
