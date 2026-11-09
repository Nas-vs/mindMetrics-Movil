import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/evaluacion_voz_repositorio.dart';
import '../domain/dialogo/guion.dart';
import '../domain/personaje_avatar.dart';
import 'avatar_controlador.dart';
import 'avatar_mascota.dart';
import 'conversacion_controlador.dart';

/// Pantalla de conversación (sin lógica): avatar, subtítulo, historial,
/// opciones, entrada de texto, ayuda en crisis y estados de micrófono.
///
/// La usan la página real (`ConversacionPagina`) y el banco de pruebas.
class ConversacionVista extends StatefulWidget {
  const ConversacionVista({
    super.key,
    required this.conversacion,
    required this.avatar,
    required this.personaje,
    this.alTerminar,
  });

  final ConversacionControlador conversacion;
  final AvatarControlador avatar;
  final PersonajeAvatar personaje;

  /// Contenido al final cuando la evaluación quedó guardada.
  final WidgetBuilder? alTerminar;

  @override
  State<ConversacionVista> createState() => _ConversacionVistaState();
}

class _ConversacionVistaState extends State<ConversacionVista> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  /// Mensajes y estado ya mostrados: si cambia cualquiera, se baja al final
  /// (p. ej. la ayuda de crisis aparece DESPUÉS del último mensaje y debe
  /// quedar a la vista).
  (int, EstadoConversacion)? _vistoHasta;

  ConversacionControlador get _c => widget.conversacion;

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _enviar() {
    final t = _texto.text;
    _texto.clear();
    _c.responderTexto(t);
  }

  void _bajarSiHayNuevos() {
    final ahora = (_c.historial.length, _c.estado);
    if (ahora == _vistoHasta) return;
    _vistoHasta = ahora;
    WidgetsBinding.instance.addPostFrameCallback((_) => _irAlFinal());
  }

  Future<void> _irAlFinal() async {
    if (!_scroll.hasClients) return;
    await _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    // El ListView mide sus hijos al llegar a ellos: si al bajar apareció
    // más contenido (la tarjeta de crisis es alta), el final se movió.
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels < p.maxScrollExtent) _scroll.jumpTo(p.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        _bajarSiHayNuevos();
        final turno = _c.turno;
        final estado = _c.estado;
        final abierta = _c.sesion.esperaRespuesta;
        final delAvatar = _c.historial.where((m) => m.deAvatar);
        final ultimo = delAvatar.isEmpty ? null : delAvatar.last;

        return Column(
          children: [
            const SizedBox(height: 8),
            AvatarMascota(personaje: widget.personaje, controlador: widget.avatar, tamano: 170),
            if (ultimo != null)
              // Subtítulo: lo que dice el avatar, para leerlo además de oírlo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  ultimo.texto,
                  key: const ValueKey('subtitulo'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            _EstadoMicrofono(estado: estado, onSeguir: _c.seguir),
            LinearProgressIndicator(value: turno?.progreso ?? 0),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final m in _c.historial) _Burbuja(mensaje: m),
                  if (estado == EstadoConversacion.crisis) _AyudaCrisis(lineas: _c.lineasCrisis),
                  if (estado == EstadoConversacion.error)
                    _ErrorGuardado(error: _c.error, onReintentar: _c.reintentarGuardado),
                  if (estado == EstadoConversacion.terminada && widget.alTerminar != null)
                    widget.alTerminar!(context),
                ],
              ),
            ),
            if (turno != null && turno.opciones.isNotEmpty && abierta)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in turno.opciones)
                      ActionChip(label: Text(o.etiqueta), onPressed: () => _c.elegir(o)),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('entrada'),
                        controller: _texto,
                        enabled: abierta,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviar(),
                        decoration: const InputDecoration(hintText: 'También puedes escribir…'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Enviar',
                      onPressed: abierta ? _enviar : null,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EstadoMicrofono extends StatelessWidget {
  const _EstadoMicrofono({required this.estado, required this.onSeguir});

  final EstadoConversacion estado;
  final VoidCallback onSeguir;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return switch (estado) {
      EstadoConversacion.escuchando => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Chip(
            key: const ValueKey('escuchando'),
            avatar: Icon(Icons.mic, color: esquema.primary),
            label: const Text('Te escucho…'),
          ),
        ),
      EstadoConversacion.pausada => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: FilledButton.tonalIcon(
            key: const ValueKey('seguir'),
            onPressed: onSeguir,
            icon: const Icon(Icons.mic),
            label: const Text('Toca para seguir hablando'),
          ),
        ),
      EstadoConversacion.guardando => const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Guardando tus respuestas…'),
        ),
      _ => const SizedBox(height: 6),
    };
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final MensajeChat mensaje;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final deAvatar = mensaje.deAvatar;
    return Align(
      alignment: deAvatar ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: deAvatar ? esquema.surface : esquema.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: esquema.outline),
        ),
        child: Text(mensaje.texto,
            style: TextStyle(color: deAvatar ? esquema.onSurface : esquema.onPrimary)),
      ),
    );
  }
}

/// Líneas de ayuda con botón para llamar.
class _AyudaCrisis extends StatelessWidget {
  const _AyudaCrisis({required this.lineas});

  final List<LineaAyuda> lineas;

  Future<void> _llamar(BuildContext context, String numero) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: numero)).catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Marca el $numero desde tu teléfono.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('ayuda_crisis'),
      color: Theme.of(context).colorScheme.tertiary,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('No estás solo. Puedes hablar ahora con alguien:',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final l in lineas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FilledButton.tonalIcon(
                  onPressed: () => _llamar(context, l.numero),
                  icon: const Icon(Icons.call),
                  label: Text('${l.nombre} · ${l.numero}\n${l.horario}', textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorGuardado extends StatelessWidget {
  const _ErrorGuardado({required this.error, required this.onReintentar});

  final Object? error;
  final Future<void> Function() onReintentar;

  String get _mensaje => switch (error) {
        EvaluacionExcepcion(tipo: ErrorEvaluacion.yaExiste) =>
          'Ya tienes una evaluación inicial registrada.',
        EvaluacionExcepcion(tipo: ErrorEvaluacion.sinConexion) =>
          'No hay conexión. Tus respuestas siguen aquí: inténtalo de nuevo.',
        EvaluacionExcepcion(tipo: ErrorEvaluacion.sinPermiso) =>
          'Tu sesión venció. Vuelve a iniciar sesión e inténtalo de nuevo.',
        _ => 'No se pudieron guardar tus respuestas. Inténtalo de nuevo.',
      };

  @override
  Widget build(BuildContext context) {
    final yaExiste = error is EvaluacionExcepcion &&
        (error! as EvaluacionExcepcion).tipo == ErrorEvaluacion.yaExiste;
    return Card(
      key: const ValueKey('error_guardado'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_mensaje),
            if (!yaExiste) ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
