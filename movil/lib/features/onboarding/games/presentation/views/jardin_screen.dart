import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../domain/planta.dart';
import '../viewmodels/jardin_viewmodel.dart';

/// Pantalla visual e inmersiva del Jardín Emocional (RF-16).
class JardinScreen extends StatefulWidget {
  const JardinScreen({super.key, this.viewModel});

  final JardinViewModel? viewModel;

  @override
  State<JardinScreen> createState() => _JardinScreenState();
}

class _JardinScreenState extends State<JardinScreen>
    with TickerProviderStateMixin {
  late final JardinViewModel _vm;
  late final AnimationController _respiracionCtrl;
  late final AnimationController _riegoCtrl;
  late final AnimationController _mariposaCtrl;

  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? JardinViewModel();

    // Animación suave de "respiración" de la planta
    _respiracionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Animación de la regadera y las gotas
    _riegoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Animación de la mariposa volando
    _mariposaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _respiracionCtrl.dispose();
    _riegoCtrl.dispose();
    _mariposaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ejecutarRiego() async {
    if (_vm.gotasDisponibles <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '💧 Registra tu ánimo diario en el Inicio para ganar más gotas.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _riegoCtrl.forward(from: 0.0);
    final exito = await _vm.regarPlanta();
    if (exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryTeal,
          content: Text(
            '✨ ¡${_vm.planta?.nombre ?? "Tu planta"} recibió agua con gratitud!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.cargando) {
          return const Scaffold(
            backgroundColor: Color(0xFFF1F8E9),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            ),
          );
        }

        // CA-1: Si aún no tiene planta, abre la pantalla de adopción
        if (!_vm.tienePlanta) {
          return _PantallaAdopcion(onAdoptar: _vm.adoptarPlanta);
        }

        final planta = _vm.planta!;
        final decoraciones = _vm.decoracionesDesbloqueadas;

        return Scaffold(
          body: Stack(
            children: [
              // 1. Fondo degradado de cielo zen a colina verde
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE0F7FA), // Celeste cielo suave
                      Color(0xFFE8F5E9), // Verde menta
                      Color(0xFFC8E6C9), // Verde colina
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // Sol cálido en el fondo
              Positioned(
                top: 40,
                right: 30,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Colina de tierra fértil en la base
              Positioned(
                bottom: -60,
                left: -40,
                right: -40,
                height: 240,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF81C784).withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.elliptical(300, 120),
                    ),
                  ),
                ),
              ),

              // 3. Contenido principal
              SafeArea(
                child: Column(
                  children: [
                    // Barra superior: botón regresar y racha
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.textDark,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          // Indicador de Racha (CA-5)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_vm.diasRacha} días',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CA-4: Cartelito de bienvenida si estuvo ausente
                    if (_vm.mostrarMensajeEsperando)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 6),
                            ],
                            border: Border.all(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🌱', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '¡Tu jardín te estaba esperando!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primaryTeal,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _vm.descartarMensajeEsperando,
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Tarjeta de progreso de la planta (CA-3)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 6,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planta.nombre,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      planta.tipo.nombre,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: planta.tipo.color,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTeal.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Etapa ${planta.etapa}/7',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryTeal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Barra de crecimiento hacia la etapa 7
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: planta.progresoTotal,
                                minHeight: 8,
                                backgroundColor: Colors.black12,
                                color: planta.tipo.color,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              planta.etapa >= 7
                                  ? '🎉 ¡Tu planta ha alcanzado su máximo florecimiento!'
                                  : 'Faltan ${planta.riegosParaSiguienteEtapa} riego(s) para avanzar de etapa',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // CA-6: Burbuja flotante con frase de ánimo al tocar la planta
                    if (_vm.mensajeAnimo != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: 1.0,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '💬',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _vm.mensajeAnimo!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _vm.cerrarMensajeAnimo,
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // 4. Escenario Central: La Planta, Decoraciones y Maceta
                    SizedBox(
                      height: 260,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // CA-5: Decoración de la Banca (14 días)
                          if (decoraciones.contains(DecoracionJardin.banca))
                            Positioned(
                              left: 30,
                              bottom: 20,
                              child: const Text(
                                '🪑',
                                style: TextStyle(fontSize: 48),
                              ),
                            ),

                          // CA-5: Decoración del Farol (30 días)
                          if (decoraciones.contains(DecoracionJardin.farol))
                            Positioned(
                              right: 35,
                              bottom: 25,
                              child: const Text(
                                '🏮',
                                style: TextStyle(fontSize: 46),
                              ),
                            ),

                          // CA-5: Decoración de la Mariposa flotando (7 días)
                          if (decoraciones.contains(DecoracionJardin.mariposa))
                            AnimatedBuilder(
                              animation: _mariposaCtrl,
                              builder: (context, child) {
                                return Positioned(
                                  top: 10 + (_mariposaCtrl.value * 20),
                                  right: 60 + (_mariposaCtrl.value * 25),
                                  child: Transform.rotate(
                                    angle: (_mariposaCtrl.value - 0.5) * 0.2,
                                    child: const Text(
                                      '🦋',
                                      style: TextStyle(fontSize: 32),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Planta con animación de respiración y toque (CA-6)
                          GestureDetector(
                            onTap: _vm.tocarPlanta,
                            child: AnimatedBuilder(
                              animation: _respiracionCtrl,
                              builder: (context, child) {
                                final escala =
                                    1.0 + (_respiracionCtrl.value * 0.04);
                                return Transform.scale(
                                  scale: escala,
                                  child: child,
                                );
                              },
                              child: _VisualPlanta(planta: planta),
                            ),
                          ),

                          // Animación de gotas cayendo cuando se riega (CA-2)
                          if (_vm.regando)
                            Positioned(
                              top: 20,
                              child: AnimatedBuilder(
                                animation: _riegoCtrl,
                                builder: (context, _) {
                                  return Opacity(
                                    opacity: 1.0 - _riegoCtrl.value,
                                    child: Transform.translate(
                                      offset: Offset(0, _riegoCtrl.value * 100),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '💧',
                                            style: TextStyle(fontSize: 22),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '💧',
                                            style: TextStyle(fontSize: 26),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '💧',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // 5. Botón Flotante de la Regadera (CA-2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: GestureDetector(
                        onTap: _vm.regando ? null : _ejecutarRiego,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF26A69A),
                                AppColors.primaryTeal,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryTeal.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.water_drop_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _vm.regando ? 'Regando...' : 'Regar planta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Contador de gotas disponibles
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_vm.gotasDisponibles} 💧',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Representación gráfica de la planta y maceta según su etapa (1 a 7).
class _VisualPlanta extends StatelessWidget {
  const _VisualPlanta({required this.planta});

  final Planta planta;

  String _emojiSegunEtapa() {
    switch (planta.etapa) {
      case 1:
        return '🌱'; // Semilla / brote recién nacido
      case 2:
        return '🌿'; // Pequeño tallo con hojas
      case 3:
        return planta.tipo == TipoPlanta.cactus ? '🌵' : '🪴';
      case 4:
        return planta.tipo == TipoPlanta.cactus ? '🌵' : '🌸';
      case 5:
        return planta.tipo == TipoPlanta.girasol
            ? '🌻'
            : (planta.tipo == TipoPlanta.cactus ? '🌵' : '🌳');
      case 6:
        return planta.tipo.emoji;
      case 7:
        return planta.tipo.emoji; // Planta en máxima madurez
      default:
        return planta.tipo.emoji;
    }
  }

  double _tamanoSegunEtapa() {
    // Crece progresivamente de 50px a 115px
    return 50.0 + (planta.etapa * 9.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Halo de luz dorada si está en etapa 7 (madurez)
        Container(
          decoration: planta.etapa == 7
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                )
              : null,
          child: Text(
            _emojiSegunEtapa(),
            style: TextStyle(fontSize: _tamanoSegunEtapa()),
          ),
        ),

        // Maceta cerámica
        Container(
          width: 100,
          height: 55,
          decoration: BoxDecoration(
            color: const Color(0xFFD87D4A), // Color terracota
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFBF6432), width: 3),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 80,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

/// CA-1: Pantalla inicial de bienvenida y adopción de la planta.
class _PantallaAdopcion extends StatefulWidget {
  const _PantallaAdopcion({required this.onAdoptar});

  final Future<void> Function(TipoPlanta tipo, String nombre) onAdoptar;

  @override
  State<_PantallaAdopcion> createState() => _PantallaAdopcionState();
}

class _PantallaAdopcionState extends State<_PantallaAdopcion> {
  TipoPlanta _seleccionada = TipoPlanta.girasol;
  final _nombreCtrl = TextEditingController(text: 'Solcito');

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Bienvenido a tu Jardín',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Elige tu primera planta para empezar a cultivar tu bienestar diario.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Opciones de las 3 plantas (CA-1)
              Expanded(
                child: ListView(
                  children: TipoPlanta.values.map((tipo) {
                    final activa = _seleccionada == tipo;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _seleccionada = tipo;
                          if (_nombreCtrl.text.isEmpty ||
                              TipoPlanta.values.any(
                                (t) => t.nombre == _nombreCtrl.text,
                              )) {
                            _nombreCtrl.text = tipo.nombre;
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: activa ? tipo.color : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              tipo.emoji,
                              style: const TextStyle(fontSize: 40),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tipo.nombre,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tipo.significado,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (activa)
                              Icon(
                                Icons.check_circle_rounded,
                                color: tipo.color,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Campo para nombrarla (CA-1)
              TextField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre para tu planta',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Botón Adoptar
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    widget.onAdoptar(_seleccionada, _nombreCtrl.text);
                  },
                  child: const Text(
                    'Plantar en mi jardín',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
