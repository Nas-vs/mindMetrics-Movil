import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tema/app_tema.dart';
import '../../../core/widgets/fondo_mindmetrics.dart';
import '../../auth/compartido/presentation/fondo_auth.dart';

import '../../recordatorio/data/recordatorio_servicio.dart';
import '../../recordatorio/presentation/beneficio_recordatorio_hoja.dart';
import '../data/registro_animo_repositorio.dart';
import '../domain/registro_animo.dart';
import 'registro_animo_vista_modelo.dart';

/// RF-08: registro rápido de ánimo. Se abre con el botón (+) del Inicio y
/// desde la notificación de RF-22 (ruta `Rutas.encuesta`).
class RegistroAnimoPagina extends ConsumerStatefulWidget {
  const RegistroAnimoPagina({super.key});

  @override
  ConsumerState<RegistroAnimoPagina> createState() => _RegistroAnimoPaginaState();
}

class _RegistroAnimoPaginaState extends ConsumerState<RegistroAnimoPagina> {
  late final RegistroAnimoVistaModelo _vm =
      RegistroAnimoVistaModelo(ref.read(registroAnimoRepositorioProvider))
        ..addListener(_mostrarAviso)
        ..cargar();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _mostrarAviso() {
    final aviso = _vm.aviso;
    if (aviso == null || !mounted) return;
    _vm.limpiarAviso();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
  }

  Future<void> _guardar() async {
    final resultado = await _vm.guardar();
    if (resultado == null || !mounted) return;

    animoGuardado.value++; // RF-09: la recomendación depende del ánimo
    final mensajero = ScaffoldMessenger.of(context);
    mensajero.showSnackBar(SnackBar(
      content: Text(resultado == ResultadoGuardado.sincronizado
          ? 'Registro guardado'
          : 'Sin conexión: lo guardamos en el celular y se enviará después'),
    ));

    // CA-8: la alerta solo existe si el registro llegó al servidor.
    if (resultado == ResultadoGuardado.sincronizado) {
      final alerta = await _vm.alertaPendiente();
      if (alerta != null && mounted) {
        await _mostrarAlerta(alerta);
        await _vm.marcarAlertaVista(alerta.id);
      }
    }

    // RF-22 CA-1: cancela el recordatorio de hoy y, la primera vez, ofrece
    // activarlo.
    if (!mounted) return;
    await ref.read(recordatorioServicioProvider).despuesDeRegistrarAnimo(
          preguntarAlUsuario: () => mostrarBeneficioRecordatorio(context),
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _mostrarAlerta(AlertaBienestar alerta) {
    final texto = switch (alerta.motivo) {
      'riesgo_alto' =>
        'Notamos que estos días han sido difíciles. No tienes que pasarlo solo.',
      'muy_bajo_seguido' =>
        'Llevas dos días sintiéndote muy mal. Hablar con alguien puede ayudar.',
      _ => 'Tus últimos registros han sido bajos. ¿Quieres apoyo?',
    };
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.favorite_outline),
        title: const Text('Estamos contigo'),
        content: Text('$texto\n\nSi estás en peligro, llama a la línea 106 o al 123.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => FondoMindMetrics(
        contenido: _vm.cargando
            ? const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                children: [
                  const IconoCircular(Icons.favorite_rounded),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppMedidas.relleno),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TituloTarjeta(_vm.esEdicion
                              ? 'Edita cómo te sientes hoy'
                              : '¿Cómo te sientes hoy?'),
                          const SizedBox(height: 10),
                          Text(
                            'Elige cómo estás con un toque.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColores.texto),
                          ),
                          const SizedBox(height: 20),
                          _SelectorNivel(
                            seleccionado: _vm.nivel,
                            alElegir: _vm.elegirNivel,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: EnlaceAuth(
                              texto: _vm.panelAbierto
                                  ? 'Ocultar detalles'
                                  : 'Agregar detalles (opcional)',
                              onPressed: _vm.alternarPanel,
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.topCenter,
                            child: _vm.panelAbierto
                                ? _PanelDetalle(vm: _vm)
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        pie: BotonConLogo(
          texto: _vm.esEdicion ? 'Actualizar' : 'Guardar',
          cargando: _vm.guardando,
          onPressed: _vm.puedeGuardar ? _guardar : null,
        ),
      ),
    );
  }
}

/// CA-2: cinco emojis, uno seleccionado a la vez. Debajo se muestra la
/// etiqueta del elegido.
class _SelectorNivel extends StatelessWidget {
  const _SelectorNivel({required this.seleccionado, required this.alElegir});
  final int? seleccionado;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final n in NivelAnimo.todos)
              Semantics(
                button: true,
                selected: n.valor == seleccionado,
                label: n.etiqueta,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => alElegir(n.valor),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: n.valor == seleccionado
                          ? AppColores.primario.withValues(alpha: .15)
                          : Colors.transparent,
                      border: Border.all(
                        color: n.valor == seleccionado
                            ? AppColores.primario
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: n.valor == seleccionado ? 1.15 : 1,
                      child: Text(n.emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 22,
          child: Text(
            seleccionado == null ? '' : NivelAnimo.de(seleccionado!).etiqueta,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColores.primario,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

/// CA-4: emociones, factores y nota (todo opcional), con las mismas
/// etiquetas sobre el campo que el registro (RF-03).
class _PanelDetalle extends StatelessWidget {
  const _PanelDetalle({required this.vm});
  final RegistroAnimoVistaModelo vm;

  @override
  Widget build(BuildContext context) {
    Widget chips(List<OpcionCatalogo> opciones, Set<int> elegidos,
            ValueChanged<int> alternar) =>
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in opciones)
              FilterChip(
                label: Text(o.nombre),
                selected: elegidos.contains(o.id),
                selectedColor: AppColores.acento,
                checkmarkColor: AppColores.primario,
                side: const BorderSide(color: AppColores.borde),
                onSelected: (_) => alternar(o.id),
              ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoConEtiqueta(
            etiqueta: '¿Qué emociones sentiste?',
            child: chips(vm.emociones, vm.emocionesElegidas, vm.alternarEmocion),
          ),
          CampoConEtiqueta(
            etiqueta: '¿Qué influyó?',
            child: chips(vm.factores, vm.factoresElegidos, vm.alternarFactor),
          ),
          CampoConEtiqueta(
            etiqueta: 'Nota',
            child: TextFormField(
              initialValue: vm.nota,
              onChanged: vm.cambiarNota,
              maxLength: RegistroAnimoVistaModelo.maxNota,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Escribe lo que quieras recordar de hoy',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
