import 'package:flutter/material.dart';

import '../data/evaluacion_voz_repositorio.dart';
import '../data/guion_repositorio.dart';
import '../data/voz/voz_dispositivo.dart';
import '../domain/dialogo/guion.dart';
import '../domain/personaje_avatar.dart';
import '../domain/servicio_voz.dart';
import 'avatar_controlador.dart';
import 'consentimiento_voz.dart';
import 'conversacion_controlador.dart';
import 'conversacion_vista.dart';

/// Cómo terminó la conversación. Se entrega a [ConversacionPagina.alSalir]
/// o, si no se da, se devuelve con `Navigator.pop`.
enum ResultadoConversacion { guardada, formulario, cancelada }

/// Voz lista para usar, o `null` con el aviso que se le muestra al usuario.
typedef PrepararVoz = Future<(ServicioVoz?, String?)> Function();

/// Evaluación inicial conversando con la mascota (ruta `Rutas.avatar`).
///
/// 1. Pregunta cómo quiere responder (voz, escribiendo o formulario).
/// 2. Si eligió voz, pide permisos; si algo falla, sigue escribiendo.
/// 3. Al terminar guarda en `evaluaciones_iniciales` (canal = voz).
///
/// El avatar saluda y se despide con [apodo] (el nickname del registro).
class ConversacionPagina extends StatefulWidget {
  const ConversacionPagina({
    super.key,
    this.personaje = PersonajesAvatar.nimbus,
    this.repositorioGuion = const GuionRepositorio(),
    this.guardar,
    this.prepararVoz = vozDelDispositivo,
    this.elegirModo,
    this.alTerminar,
    this.apodo,
    this.alSalir,
  });

  final PersonajeAvatar personaje;
  final GuionRepositorio repositorioGuion;

  /// Por defecto `EvaluacionVozRepositorio().guardar` (Supabase).
  final Future<void> Function(Map<String, Object> fila)? guardar;
  final PrepararVoz prepararVoz;

  /// Por defecto, la hoja de consentimiento de voz.
  final Future<ModoConversacion?> Function(BuildContext context)? elegirModo;

  /// Contenido al terminar; por defecto un aviso y el botón "Continuar".
  final WidgetBuilder? alTerminar;

  /// Nickname del registro (RF-07). `null` → saludo sin nombre.
  final String? apodo;

  /// Qué hacer al salir. En la app el router navega al Inicio (la página se
  /// abre con `go`, no hay a dónde volver). Por defecto, `Navigator.pop`.
  final void Function(ResultadoConversacion resultado)? alSalir;

  @override
  State<ConversacionPagina> createState() => _ConversacionPaginaState();
}

/// Prepara speech_to_text + flutter_tts. En plataformas sin soporte (web,
/// escritorio) o sin permisos devuelve el aviso y la app sigue por texto.
Future<(ServicioVoz?, String?)> vozDelDispositivo() async {
  try {
    final voz = VozDispositivo();
    return switch (await voz.preparar()) {
      DisponibilidadVoz.lista => (voz, null),
      DisponibilidadVoz.sinPermiso => (null, 'Sin permiso de micrófono: seguimos escribiendo.'),
      DisponibilidadVoz.sinReconocedor => (null, 'Este dispositivo no reconoce voz: seguimos escribiendo.'),
      DisponibilidadVoz.sinEspanol => (null, 'No hay voz en español instalada: seguimos escribiendo.'),
    };
  } catch (_) {
    return (null, 'La voz no está disponible aquí: seguimos escribiendo.');
  }
}

class _ConversacionPaginaState extends State<ConversacionPagina> {
  final _avatar = AvatarControlador();
  ConversacionControlador? _conversacion;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arrancar());
  }

  Future<void> _arrancar() async {
    final Guion guion;
    try {
      guion = await widget.repositorioGuion.cargar();
    } catch (e) {
      if (mounted) setState(() => _errorCarga = '$e');
      return;
    }
    if (!mounted) return;

    final modo = await (widget.elegirModo ?? _hojaConsentimiento)(context);
    if (!mounted) return;
    if (modo == null || modo == ModoConversacion.formulario) {
      _salir(modo == null ? ResultadoConversacion.cancelada : ResultadoConversacion.formulario);
      return;
    }

    ServicioVoz voz = VozSoloTexto(msPorPalabra: 60);
    if (modo == ModoConversacion.voz) {
      final (vozLista, aviso) = await widget.prepararVoz();
      if (!mounted) return;
      if (vozLista != null) {
        voz = vozLista;
      } else if (aviso != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
      }
    }

    final c = ConversacionControlador(
      guion: guion,
      voz: voz,
      avatar: _avatar,
      mascota: widget.personaje.nombre,
      apodo: widget.apodo,
      guardar: widget.guardar ?? EvaluacionVozRepositorio().guardar,
    )..addListener(_alCambiar);
    setState(() => _conversacion = c);
    await c.iniciar();
  }

  Future<ModoConversacion?> _hojaConsentimiento(BuildContext context) =>
      pedirModoConversacion(context, mascota: widget.personaje.nombre);

  void _alCambiar() {
    if (_conversacion?.estado == EstadoConversacion.formulario) {
      _salir(ResultadoConversacion.formulario);
    }
  }

  bool _salio = false;

  void _salir(ResultadoConversacion resultado) {
    if (_salio || !mounted) return;
    _salio = true;
    final alSalir = widget.alSalir;
    if (alSalir != null) {
      alSalir(resultado);
    } else {
      Navigator.of(context).pop(resultado);
    }
  }

  @override
  void dispose() {
    _conversacion?.dispose();
    _avatar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _conversacion;
    return Scaffold(
      appBar: AppBar(title: Text('Conversa con ${widget.personaje.nombre}')),
      body: _errorCarga != null
          ? Center(child: Text('No se pudo cargar la conversación.\n$_errorCarga', textAlign: TextAlign.center))
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : ConversacionVista(
                  conversacion: c,
                  avatar: _avatar,
                  personaje: widget.personaje,
                  alTerminar: widget.alTerminar ?? _terminado,
                ),
    );
  }

  Widget _terminado(BuildContext context) => Card(
        key: const ValueKey('terminado'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('¡Listo! Tus respuestas quedaron guardadas. '
                  'En unos segundos se calcula tu nivel.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _salir(ResultadoConversacion.guardada),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      );
}
