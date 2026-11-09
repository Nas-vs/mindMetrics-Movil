import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/capas_avatar.dart';
import '../domain/estado_avatar.dart';
import '../domain/generador_silabas.dart';
import '../domain/personaje_avatar.dart';
import 'avatar_controlador.dart';

/// Dibuja el avatar animado apilando sus capas SVG.
///
/// El arte vive en `assets/avatar/<personaje>/` y el comportamiento aquí:
/// - Respiración/flotación según [PersonajeAvatar.movimiento].
/// - Parpadeo aleatorio cada 2,5–5,5 s.
/// - Boca sincronizada con [AvatarControlador.nivelVoz] o, si nadie envía
///   ese nivel, con un ritmo de sílabas simulado.
/// - Anillo pulsante al escuchar y burbujas al pensar.
///
/// Todas las variantes de ojos y boca quedan montadas y solo cambia su
/// opacidad: así no hay parpadeos de carga al pasar de un visema a otro.
/// Respeta "reducir movimiento" del sistema (sin flotar ni balancearse).
class AvatarMascota extends StatefulWidget {
  const AvatarMascota({
    super.key,
    required this.personaje,
    required this.controlador,
    this.tamano = 200,
  });

  final PersonajeAvatar personaje;
  final AvatarControlador controlador;

  /// Lado del cuadro donde se dibuja (el arte es cuadrado).
  final double tamano;

  @override
  State<AvatarMascota> createState() => _AvatarMascotaState();
}

class _AvatarMascotaState extends State<AvatarMascota>
    with SingleTickerProviderStateMixin {
  static const _duracionParpadeo = Duration(milliseconds: 140);

  late final _ticker = createTicker(_alTick);
  final _tiempo = ValueNotifier<Duration>(Duration.zero);
  final _silabas = GeneradorSilabas();
  final _rnd = math.Random();

  Duration _anterior = Duration.zero;
  Duration _proximoParpadeo = const Duration(milliseconds: 1800);
  Duration _finParpadeo = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  void _alTick(Duration transcurrido) {
    final dt = transcurrido - _anterior;
    _anterior = transcurrido;

    final c = widget.controlador;
    if (c.estado.actividad == ActividadAvatar.hablando) {
      if (!c.usaNivelExterno) _silabas.avanzar(dt);
    } else if (_silabas.nivel != 0) {
      _silabas.reiniciar();
    }

    if (transcurrido >= _proximoParpadeo) {
      _finParpadeo = transcurrido + _duracionParpadeo;
      // 1 de cada 6 veces, parpadeo doble (se ve más natural).
      final doble = _rnd.nextInt(6) == 0;
      _proximoParpadeo = transcurrido +
          (doble
              ? const Duration(milliseconds: 300)
              : Duration(milliseconds: 2500 + _rnd.nextInt(3000)));
    }
    _tiempo.value = transcurrido;
  }

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.tamano,
        child: AnimatedBuilder(
          animation: Listenable.merge([_tiempo, widget.controlador]),
          builder: (context, _) => _construir(sinMovimiento),
        ),
      ),
    );
  }

  Widget _construir(bool sinMovimiento) {
    final c = widget.controlador;
    final estado = c.estado;
    final ahora = _tiempo.value;
    final t = ahora.inMicroseconds / Duration.microsecondsPerSecond;
    final amp = sinMovimiento ? 0.0 : 1.0;
    final escala = widget.tamano / 240;

    final hablando = estado.actividad == ActividadAvatar.hablando;
    final nivel =
        hablando ? (c.usaNivelExterno ? c.nivelVoz : _silabas.nivel) : 0.0;
    final ojos = CapasAvatar.ojosPara(
      estado,
      parpadeando: !sinMovimiento && ahora < _finParpadeo,
    );
    final boca = CapasAvatar.bocaPara(
      estado,
      nivelVoz: nivel,
      vocalRedonda: !c.usaNivelExterno && _silabas.vocalRedonda,
    );

    // Ciclo de respiración (3,2 s) y balanceo lento (5,3 s).
    final onda = math.sin(2 * math.pi * t / 3.2);
    final balanceo = math.sin(2 * math.pi * t / 5.3);
    final inclinacion =
        estado.actividad == ActividadAvatar.escuchando ? 0.06 : 0.0;

    double dy = 0, rot = inclinacion * amp, sx = 1, sy = 1, sombraX = 1;
    var ancla = Alignment.center;
    switch (widget.personaje.movimiento) {
      case MovimientoAvatar.flotar:
        dy = (-6 * onda - 3 * nivel) * escala * amp;
        rot += 0.025 * balanceo * amp;
        sx = sy = 1 + 0.015 * nivel * amp;
        sombraX = 1 - 0.1 * (onda + 1) / 2 * amp;
      case MovimientoAvatar.rebotar:
        ancla = const Alignment(0, 0.75); // base de Plip (y≈210 de 240)
        sy = 1 + (0.025 * onda + 0.04 * nivel) * amp;
        sx = 1 - (0.025 * onda + 0.02 * nivel) * amp;
        sombraX = 1 + 0.04 * onda * amp;
    }

    final cuerpo = Stack(
      fit: StackFit.expand,
      children: [
        _capa(CapasAvatar.cuerpo),
        _capa(
          CapasAvatar.mejillas,
          opacidad: estado.emocion == EmocionAvatar.alegre ? 1.0 : 0.75,
        ),
        for (final o in CapaOjos.values) _capa(o.archivo, visible: o == ojos),
        for (final b in CapaBoca.values) _capa(b.archivo, visible: b == boca),
        _capa(
          CapasAvatar.extraPensando,
          visible: estado.actividad == ActividadAvatar.pensando,
          opacidad: 0.6 + 0.4 * (math.sin(2 * math.pi * t / 1.2) + 1) / 2,
        ),
      ],
    );

    return Semantics(
      image: true,
      label: '${widget.personaje.nombre}, ${estado.descripcion}',
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scaleX: sombraX,
              alignment: const Alignment(0, 0.87),
              child: _capa(CapasAvatar.sombra),
            ),
            if (estado.actividad == ActividadAvatar.escuchando)
              _anillo(t, sinMovimiento),
            Transform.translate(
              offset: Offset(0, dy),
              child: Transform.rotate(
                angle: rot,
                alignment: ancla,
                child: Transform.scale(
                  scaleX: sx,
                  scaleY: sy,
                  alignment: ancla,
                  child: cuerpo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Onda que se expande cada 1,4 s mientras el micrófono está abierto.
  Widget _anillo(double t, bool sinMovimiento) {
    final p = sinMovimiento ? 0.5 : (t % 1.4) / 1.4;
    final lado = widget.tamano * (0.7 + 0.3 * p);
    return Center(
      key: const ValueKey('avatar_anillo'),
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.personaje.colorAcento
                .withValues(alpha: 0.55 * (1 - p)),
            width: 3 * widget.tamano / 240,
          ),
        ),
      ),
    );
  }

  Widget _capa(String nombre, {bool visible = true, double opacidad = 1.0}) {
    return Opacity(
      key: ValueKey('capa_$nombre'),
      opacity: visible ? opacidad : 0.0,
      child: SvgPicture.asset(
        widget.personaje.ruta(nombre),
        fit: BoxFit.contain,
      ),
    );
  }
}
