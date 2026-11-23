import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../domain/juego.dart';
import '../../domain/sesion_juego.dart';
import '../viewmodels/ejecucion_juego_viewmodel.dart';

/// Pantalla base que envuelve la ejecución inmersiva de cualquier juego (RF-15).
class EjecucionJuegoScreen extends StatefulWidget {
  const EjecucionJuegoScreen({
    super.key,
    required this.viewModel,
    this.onSesionGuardada,
  });

  final EjecucionJuegoViewModel viewModel;
  final ValueChanged<SesionJuego>? onSesionGuardada;

  @override
  State<EjecucionJuegoScreen> createState() => _EjecucionJuegoScreenState();
}

class _EjecucionJuegoScreenState extends State<EjecucionJuegoScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // CA-2: Bloquear orientación vertical
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restaurar interfaz del sistema y orientaciones al salir
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  bool _dialogoPausaAbierto = false;

  /// CA-6: Si la app pasa a segundo plano, pausa automáticamente el juego.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Solo cuando realmente pasa a segundo plano (se minimiza la app o llamada)
    if (state == AppLifecycleState.paused) {
      if (widget.viewModel.fase == FaseJuego.jugando && !_dialogoPausaAbierto) {
        _mostrarDialogoPausa();
      }
    }
  }

  void _activarModoInmersivo() {
    // CA-2: Pantalla completa sin barras de estado ni navegación
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restaurarBarras() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// CA-4 y CA-5: Menú modal de pausa.
  Future<void> _mostrarDialogoPausa() async {
    if (_dialogoPausaAbierto) return;
    _dialogoPausaAbierto = true;

    widget.viewModel.pausarJuego();
    _restaurarBarras();

    final accion = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_rounded, color: AppColors.primaryTeal),
            SizedBox(width: 8),
            Text('Juego en pausa'),
          ],
        ),
        content: const Text('¿Qué deseas hacer con tu actividad actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'salir'),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'reiniciar'),
            child: const Text('Reiniciar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
            ),
            onPressed: () => Navigator.pop(ctx, 'continuar'),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    _dialogoPausaAbierto = false;

    if (!mounted) return;

    if (accion == 'salir') {
      Navigator.pop(context);
    } else if (accion == 'reiniciar') {
      _activarModoInmersivo();
      widget.viewModel.reiniciarJuego();
    } else {
      _activarModoInmersivo();
      widget.viewModel.reanudarJuego();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final fase = widget.viewModel.fase;

        // CA-5: Interceptar botón atrás del sistema para abrir pausa
        return PopScope(
          canPop: fase == FaseJuego.intro || fase == FaseJuego.finalizado,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && fase == FaseJuego.jugando) {
              _mostrarDialogoPausa();
            }
          },
          child: Scaffold(
            backgroundColor: widget.viewModel.juego.colorFondo,
            body: SafeArea(
              child: switch (fase) {
                FaseJuego.intro => _VistaIntro(
                  juego: widget.viewModel.juego,
                  animoSeleccionado: widget.viewModel.animoInicial,
                  onSeleccionarAnimo: widget.viewModel.seleccionarAnimoInicial,
                  onComenzar: () {
                    _activarModoInmersivo();
                    widget.viewModel.comenzarJuego();
                  },
                ),
                FaseJuego.jugando || FaseJuego.pausado => _VistaPartidaActiva(
                  juego: widget.viewModel.juego,
                  segundos: widget.viewModel.segundosTranscurridos,
                  onPausar: _mostrarDialogoPausa,
                  onCompletar: () {
                    _restaurarBarras();
                    widget.viewModel.finalizarJuego();
                  },
                ),
                FaseJuego.finalizado => _VistaCierre(
                  viewModel: widget.viewModel,
                  onVolver: () {
                    final sesion = widget.viewModel.generarSesion();
                    widget.onSesionGuardada?.call(sesion);
                    Navigator.pop(context);
                  },
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

/// CA-1: Pantalla previa con objetivo, cómo se juega y ánimo inicial.
class _VistaIntro extends StatelessWidget {
  const _VistaIntro({
    required this.juego,
    required this.animoSeleccionado,
    required this.onSeleccionarAnimo,
    required this.onComenzar,
  });

  final Juego juego;
  final int? animoSeleccionado;
  final ValueChanged<int?> onSeleccionarAnimo;
  final VoidCallback onComenzar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Chip(
                backgroundColor: Colors.white,
                avatar: Icon(
                  juego.objetivo.icono,
                  size: 14,
                  color: juego.objetivo.color,
                ),
                label: Text(
                  juego.objetivo.etiqueta,
                  style: TextStyle(
                    fontSize: 11,
                    color: juego.objetivo.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Icono principal
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(juego.icono, size: 54, color: juego.objetivo.color),
          ),
          const SizedBox(height: 20),

          Text(
            juego.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),

          // CA-1: Cómo se juega (máx 3 líneas)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: AppColors.accentOrange,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cómo se juega',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  juego.descripcionCorta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // CA-1: Pregunta opcional "¿Cómo te sientes ahora?"
          const Text(
            '¿Cómo te sientes ahora?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _SelectorEmojis(
            seleccionado: animoSeleccionado,
            onSeleccionar: onSeleccionarAnimo,
          ),

          const Spacer(),

          // Botones Omitir / Comenzar
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onComenzar,
                  child: const Text(
                    'Omitir',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onComenzar,
                  child: const Text(
                    'Comenzar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// CA-2, CA-3 y CA-4: Vista de juego activo con botón de pausa visible.
class _VistaPartidaActiva extends StatelessWidget {
  const _VistaPartidaActiva({
    required this.juego,
    required this.segundos,
    required this.onPausar,
    required this.onCompletar,
  });

  final Juego juego;
  final int segundos;
  final VoidCallback onPausar;
  final VoidCallback onCompletar;

  String _formatoTiempo(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final seg = (s % 60).toString().padLeft(2, '0');
    return '$m:$seg';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Barra superior con botón de pausa (CA-4) y cronómetro
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 36,
                  color: AppColors.textDark,
                ),
                onPressed: onPausar,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatoTiempo(segundos),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Canvas central interactivo del juego
          Icon(juego.icono, size: 90, color: juego.objetivo.color),
          const SizedBox(height: 16),
          Text(
            juego.nombre,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '¡Respira y concéntrate en tu momento!',
            style: TextStyle(color: AppColors.textMuted),
          ),

          const Spacer(),

          // Botón para completar la actividad
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text(
                'Completar sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: onCompletar,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// CA-7: Pantalla de cierre con mensaje positivo y comparativa de ánimo.
class _VistaCierre extends StatelessWidget {
  const _VistaCierre({required this.viewModel, required this.onVolver});

  final EjecucionJuegoViewModel viewModel;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final sesion = viewModel.generarSesion();
    final mensaje = sesion.mensajeComparativo;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const Spacer(),
          const Icon(
            Icons.celebration_rounded,
            size: 70,
            color: AppColors.accentOrange,
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Excelente trabajo!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Completaste tu momento de bienestar diario.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),

          const SizedBox(height: 28),

          // CA-7: Pregunta final "¿Y ahora cómo te sientes?"
          const Text(
            '¿Y ahora cómo te sientes?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _SelectorEmojis(
            seleccionado: viewModel.animoFinal,
            onSeleccionar: (v) {
              if (v != null) viewModel.seleccionarAnimoFinal(v);
            },
          ),

          // CA-7: Comparativa amable si respondió ambas
          if (mensaje != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryTeal.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
              ),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onVolver,
              child: const Text(
                'Volver al catálogo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Selector de 5 emojis para la escala 1 a 5 de ánimo.
class _SelectorEmojis extends StatelessWidget {
  const _SelectorEmojis({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final int? seleccionado;
  final ValueChanged<int?> onSeleccionar;

  static const _emojis = [
    (1, '😫'),
    (2, '🙁'),
    (3, '😐'),
    (4, '🙂'),
    (5, '🤩'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _emojis.map((e) {
        final nivel = e.$1;
        final emoji = e.$2;
        final activo = seleccionado == nivel;

        return GestureDetector(
          onTap: () => onSeleccionar(activo ? null : nivel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: activo ? AppColors.primaryTeal : Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }
}
