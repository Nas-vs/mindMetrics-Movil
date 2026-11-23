import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/rutas.dart';
import '../../animo/domain/registro_animo.dart';
import '../../onboarding/core/constants/app_colors.dart';

/// RF-09: recomendación del día (RPC `recomendacion_del_dia`).
class Recomendacion {
  const Recomendacion({
    required this.titulo,
    required this.descripcion,
    this.accion,
    this.textoAccion,
  });
  final String titulo;
  final String descripcion;
  final String? accion;
  final String? textoAccion;

  factory Recomendacion.desdeJson(Map<String, dynamic> j) => Recomendacion(
        titulo: j['titulo'] as String,
        descripcion: j['descripcion'] as String,
        accion: j['accion'] as String?,
        textoAccion: j['texto_accion'] as String?,
      );

  /// A dónde lleva el botón. null = la pantalla aún no existe (se oculta).
  String? get ruta => switch (accion) {
        'respiracion' || 'tension' || 'memoria_emociones' || 'jardin' || 'juegos' =>
          Rutas.juegos,
        'calendario' || 'actividades' || 'habitos' => Rutas.calendario,
        'encuesta' => Rutas.encuesta,
        _ => null, // 'cita' hasta que exista RF-21
      };
}

abstract class RecomendacionRepositorio {
  Future<Recomendacion?> delDia(DateTime ahora);
}

class RecomendacionSupabase implements RecomendacionRepositorio {
  RecomendacionSupabase(this._db);
  final SupabaseClient _db;

  @override
  Future<Recomendacion?> delDia(DateTime ahora) async {
    final r = await _db.rpc('recomendacion_del_dia',
        params: {'p_fecha': fechaLocal(ahora)});
    return r == null ? null : Recomendacion.desdeJson(r as Map<String, dynamic>);
  }
}

final recomendacionRepositorioProvider = Provider<RecomendacionRepositorio>(
  (_) => RecomendacionSupabase(Supabase.instance.client),
);

/// Tarjeta del Inicio. Se recarga con [recargar] (p. ej. al volver de RF-08,
/// porque la recomendación cambia según el ánimo registrado).
class RecomendacionDiaTarjeta extends ConsumerStatefulWidget {
  const RecomendacionDiaTarjeta({super.key, this.recargar});
  final Listenable? recargar;

  @override
  ConsumerState<RecomendacionDiaTarjeta> createState() => _RecomendacionDiaTarjetaState();
}

class _RecomendacionDiaTarjetaState extends ConsumerState<RecomendacionDiaTarjeta> {
  late Future<Recomendacion?> _futuro = _cargar();

  // async: si el provider falla (p. ej. Supabase sin inicializar en
  // pruebas), el error queda en el Future y la tarjeta se oculta.
  Future<Recomendacion?> _cargar() async =>
      ref.read(recomendacionRepositorioProvider).delDia(DateTime.now());

  void _refrescar() => setState(() => _futuro = _cargar());

  @override
  void initState() {
    super.initState();
    widget.recargar?.addListener(_refrescar);
  }

  @override
  void dispose() {
    widget.recargar?.removeListener(_refrescar);
    super.dispose();
  }

  /// Misma caja que las `StatCard` del Inicio (Samuel): fondo `cardSolid`,
  /// radio 16 y sombra suave, para que la tarjeta combine con las demás.
  static final _caja = BoxDecoration(
    color: AppColors.cardSolid,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(color: Colors.black12, offset: Offset(0, 3), blurRadius: 6),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Recomendacion?>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: 96,
            decoration: _caja,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: AppColors.primaryTeal),
          );
        }
        final r = snap.data;
        if (snap.hasError || r == null) {
          // Sin red o catálogo vacío: no se muestra nada en vez de un error.
          return const SizedBox.shrink();
        }
        final ruta = r.ruta;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _caja,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recomendación del día',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.descripcion,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              if (ruta != null && r.textoAccion != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      // go para pestañas del shell, push para profundidad
                      if (ruta == Rutas.juegos) {
                        context.go(ruta);
                      } else {
                        await context.push(ruta);
                        if (mounted) _refrescar();
                      }
                    },
                    child: Text(r.textoAccion!),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
