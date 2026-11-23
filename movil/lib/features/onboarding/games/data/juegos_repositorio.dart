import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/juego.dart';
import '../domain/sesion_juego.dart';

/// Repositorio del catálogo de juegos (RF-14).
class JuegosRepositorio {
  JuegosRepositorio([this._cliente]);

  final SupabaseClient? _cliente;

  /// Catálogo oficial con los juegos incluidos en la app (CA-1 y CA-4).
  static const List<Juego> catalogoBase = [
    Juego(
      id: 'jardin_emocional',
      nombre: 'Jardín emocional',
      descripcionCorta:
          'Cuida tu planta diaria y cultiva hábitos de bienestar.',
      duracionAproximada: '2 - 3 min',
      objetivo: ObjetivoJuego.constancia,
      icono: Icons.local_florist_rounded,
      colorFondo: Color(0xFFE8F5E9),
    ),
    Juego(
      id: 'respiracion_sostenida',
      nombre: 'Respiración sostenida',
      descripcionCorta:
          'Técnicas de desactivación biológica para recobrar la calma.',
      duracionAproximada: '3 - 5 min',
      objetivo: ObjetivoJuego.relajarme,
      icono: Icons.air_rounded,
      colorFondo: Color(0xFFE0F2F1),
    ),
    Juego(
      id: 'memoria_emociones',
      nombre: 'Memoria de emociones',
      descripcionCorta:
          'Encuentra parejas de emociones y aprende a identificarlas.',
      duracionAproximada: '4 - 6 min',
      objetivo: ObjetivoJuego.conocerEmociones,
      icono: Icons.grid_view_rounded,
      colorFondo: Color(0xFFFFEBEE),
    ),
    Juego(
      id: 'tension_respiracion',
      nombre: 'Tensión y relajación',
      descripcionCorta:
          'Tensa y relaja grupos musculares para soltar el estrés.',
      duracionAproximada: '5 - 7 min',
      objetivo: ObjetivoJuego.relajarme,
      icono: Icons.accessibility_new_rounded,
      colorFondo: Color(0xFFEDE7F6),
    ),
    Juego(
      id: 'pensar_distinto',
      nombre: 'Pensar distinto',
      descripcionCorta:
          'Reencuadra distorsiones cognitivas con ejercicios prácticos.',
      duracionAproximada: '3 - 5 min',
      objetivo: ObjetivoJuego.pensarDistinto,
      icono: Icons.psychology_alt_rounded,
      colorFondo: Color(0xFFF3E5F5),
    ),
  ];

  /// CA-3: Lee el último registro de ánimo para calcular la recomendación.
  Future<int?> obtenerUltimoNivelAnimo() async {
    final cliente = _cliente;
    final usuario = cliente?.auth.currentUser;
    if (cliente == null || usuario == null) return null;

    try {
      final fila = await cliente
          .from('registros_animo')
          .select('nivel')
          .eq('usuario_id', usuario.id)
          .order('fecha', ascending: false)
          .limit(1)
          .maybeSingle();

      return fila?['nivel'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// CA-3: Regla clínica de recomendación según el ánimo (escala 1 a 5).
  String _determinarJuegoRecomendado(int? nivel) {
    return switch (nivel) {
      1 ||
      2 => 'respiracion_sostenida', // Ánimo bajo o estrés → Relajación y calma
      3 => 'memoria_emociones', // Ánimo neutro → Conocer y explorar emociones
      4 ||
      5 => 'jardin_emocional', // Ánimo positivo → Mantener hábito y constancia
      _ => 'jardin_emocional', // Sin registro previo → Bienvenida al jardín
    };
  }

  /// Retorna la lista de juegos con el recomendado en primer lugar (CA-1, CA-3).
  Future<List<Juego>> obtenerJuegos({ObjetivoJuego? filtro}) async {
    final ultimoNivel = await obtenerUltimoNivelAnimo();
    final idRecomendado = _determinarJuegoRecomendado(ultimoNivel);

    // Marcar el recomendado
    var juegos = catalogoBase.map((j) {
      return j.id == idRecomendado ? j.copyWith(recomendado: true) : j;
    }).toList();

    // Ordenar: el recomendado siempre primero (CA-3)
    juegos.sort((a, b) {
      if (a.recomendado && !b.recomendado) return -1;
      if (!a.recomendado && b.recomendado) return 1;
      return 0;
    });

    // Aplicar filtro si el usuario seleccionó un chip (CA-2)
    if (filtro != null) {
      juegos = juegos.where((j) => j.objetivo == filtro).toList();
    }

    return juegos;
  }

  /// CA-8: Guarda la sesión de juego en Supabase (o de forma segura si la tabla aún no existe).
  Future<void> registrarSesionJuego(SesionJuego sesion) async {
    final cliente = _cliente;
    final usuario = cliente?.auth.currentUser;
    if (cliente == null || usuario == null) return;

    try {
      await cliente.from('sesiones_juegos').insert({
        'usuario_id': usuario.id,
        'juego_id': sesion.juegoId,
        'animo_inicial': sesion.animoInicial,
        'animo_final': sesion.animoFinal,
        'duracion_segundos': sesion.duracionSegundos,
        'completado': sesion.completado,
        'creado_en': sesion.fecha.toIso8601String(),
      });
    } catch (_) {
      // Silencioso mientras Julián Gómez crea la tabla en el backend
    }
  }
}
