import 'package:flutter/material.dart';

import '../viewmodels/ejecucion_juego_viewmodel.dart';
import 'ejecucion_juego_screen.dart';
import '../../../core/widgets/hamburger_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../domain/juego.dart';
import '../viewmodels/games_viewmodel.dart';

/// Vista de la sección de Catálogo de Juegos (RF-14).
class GamesView extends StatelessWidget {
  const GamesView({super.key, required this.viewModel});

  final GamesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final juegos = viewModel.juegosFiltrados;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Botón de menú hamburguesa
              HamburgerButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),

              const SizedBox(height: 12),

              // Título y descripción de la sección
              const Text(
                'Juegos de bienestar',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Elige una actividad para regular tus emociones y cultivar hábitos.',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),

              const SizedBox(height: 16),

              // CA-2: Chips de filtro horizontal por objetivo
              _FiltrosObjetivo(
                filtroSeleccionado: viewModel.filtroSeleccionado,
                onSeleccionar: viewModel.seleccionarFiltro,
              ),

              const SizedBox(height: 20),

              // CA-1: Grilla de 2 columnas de juegos
              if (viewModel.cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  ),
                )
              else if (juegos.isEmpty)
                const _EstadoVacio()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: juegos.length,
                  itemBuilder: (context, index) {
                    final juego = juegos[index];
                    return _TarjetaJuego(
                      juego: juego,
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EjecucionJuegoScreen(
                              viewModel: EjecucionJuegoViewModel(juego: juego),
                              onSesionGuardada: viewModel.guardarSesion,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              // Espacio inferior para no chocar con el FloatingNavBar
              const SizedBox(height: 120),
            ],
          ),
        );
      },
    );
  }
}

/// CA-2: Fila deslizable de chips de filtro por objetivo terapéutico.
class _FiltrosObjetivo extends StatelessWidget {
  const _FiltrosObjetivo({
    required this.filtroSeleccionado,
    required this.onSeleccionar,
  });

  final ObjetivoJuego? filtroSeleccionado;
  final ValueChanged<ObjetivoJuego?> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Opción "Todos"
          ChoiceChip(
            label: const Text('Todos'),
            selected: filtroSeleccionado == null,
            onSelected: (_) => onSeleccionar(null),
            selectedColor: AppColors.primaryTeal,
            labelStyle: TextStyle(
              color: filtroSeleccionado == null
                  ? Colors.white
                  : AppColors.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 8),

          // Chips por cada objetivo del enum
          ...ObjetivoJuego.values.map((obj) {
            final activo = filtroSeleccionado == obj;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  obj.icono,
                  size: 16,
                  color: activo ? Colors.white : obj.color,
                ),
                label: Text(obj.etiqueta),
                selected: activo,
                onSelected: (_) => onSeleccionar(obj),
                selectedColor: obj.color,
                labelStyle: TextStyle(
                  color: activo ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// CA-1 y CA-3: Tarjeta individual de juego en la grilla.
class _TarjetaJuego extends StatelessWidget {
  const _TarjetaJuego({required this.juego, required this.onTap});

  final Juego juego;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: juego.recomendado
            ? const BorderSide(color: AppColors.primaryTeal, width: 2)
            : BorderSide.none,
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CA-3: Etiqueta "Recomendado para ti"
              if (juego.recomendado)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.primaryTeal,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Recomendado',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),

              // Contenedor visual del juego (Ilustración / Icono)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: juego.colorFondo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    juego.icono,
                    size: 48,
                    color: juego.objetivo.color,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Nombre del juego (CA-1)
              Text(
                juego.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 4),

              // Duración aproximada (CA-1)
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    juego.duracionAproximada,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Etiqueta de objetivo terapéutico (CA-1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: juego.objetivo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  juego.objetivo.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: juego.objetivo.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado cuando un filtro no tiene juegos asociados.
class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.sports_esports_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No hay juegos con este objetivo.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
