import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/rutas.dart';
import '../../../../core/tema/app_tema.dart';
import '../../compartido/presentation/fondo_auth.dart';
import '../data/consentimiento_repositorio.dart';
import '../domain/politica_privacidad.dart';
import 'consentimiento_estado.dart';
import 'consentimiento_vista_modelo.dart';

/// Pantalla del RF-02: Aceptación de términos y tratamiento de datos sensibles.
class ConsentimientoPagina extends ConsumerWidget {
  const ConsentimientoPagina({super.key, this.onVolver});

  /// Acción al pulsar "Atrás" / "Volver" sin aceptar.
  final VoidCallback? onVolver;

  void _manejarVolver(BuildContext context) {
    if (onVolver != null) {
      onVolver!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Rutas.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(consentimientoVistaModeloProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _manejarVolver(context);
      },
      child: FondoAuth(
        tarjeta: _CuerpoConsentimiento(
          estado: estado,
          onReintentar: () =>
              ref.read(consentimientoVistaModeloProvider.notifier).cargar(),
          onAceptar: (version) => context.go(Rutas.registro, extra: version),
          onVolver: () => _manejarVolver(context),
        ),
      ),
    );
  }
}

class _CuerpoConsentimiento extends StatelessWidget {
  const _CuerpoConsentimiento({
    required this.estado,
    required this.onReintentar,
    required this.onAceptar,
    required this.onVolver,
  });

  final ConsentimientoEstado estado;
  final VoidCallback onReintentar;
  final void Function(String version) onAceptar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (estado.cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppColores.primario),
        ),
      );
    }

    if (estado.error != null || estado.politica == null) {
      final mensaje = estado.error == ErrorConsentimiento.sinConexion
          ? 'Sin conexión. Revisa tu internet e intenta de nuevo.'
          : 'No pudimos cargar el consentimiento informado. Intenta de nuevo.';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tratamiento de datos sensibles',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleLarge?.copyWith(
              color: AppColores.primario,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(color: AppColores.texto),
          ),
          const SizedBox(height: 24),
          BotonConLogo(texto: 'Reintentar', onPressed: onReintentar),
          const SizedBox(height: 8),
          Center(
            child: EnlaceAuth(
              texto: 'Volver',
              secundario: true,
              onPressed: onVolver,
            ),
          ),
        ],
      );
    }

    final PoliticaPrivacidad politica = estado.politica!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          politica.titulo,
          textAlign: TextAlign.center,
          style: tema.textTheme.titleLarge?.copyWith(
            color: AppColores.primario,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Versión ${politica.version} · Ley 1581 de 2012',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodySmall?.copyWith(
            color: AppColores.sobreAtenuado,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColores.atenuado,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColores.borde),
          ),
          child: _TextoPoliticaLegible(contenido: politica.contenido),
        ),
        const SizedBox(height: 20),
        BotonConLogo(
          texto: 'Aceptar y continuar',
          onPressed: () => onAceptar(politica.version),
        ),
        const SizedBox(height: 6),
        Center(
          child: EnlaceAuth(
            texto: 'Volver',
            secundario: true,
            onPressed: onVolver,
          ),
        ),
      ],
    );
  }
}

/// Renderiza el texto Markdown sencillo de `politicas_privacidad.contenido`
/// (encabezados `## `, viñetas `- ` y negritas `**...**`) en texto claro.
class _TextoPoliticaLegible extends StatelessWidget {
  const _TextoPoliticaLegible({required this.contenido});

  final String contenido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lineas = contenido.split('\n');
    final widgets = <Widget>[];

    for (final cruda in lineas) {
      final linea = cruda.trim();
      if (linea.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (linea.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              linea.substring(3),
              style: tema.textTheme.titleSmall?.copyWith(
                color: AppColores.primario,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        continue;
      }
      if (linea.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: _parrafoConNegritas(linea.substring(2), tema)),
              ],
            ),
          ),
        );
        continue;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _parrafoConNegritas(linea, tema),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _parrafoConNegritas(String texto, ThemeData tema) {
    final partes = texto.split('**');
    final spans = <TextSpan>[];
    for (var i = 0; i < partes.length; i++) {
      if (partes[i].isEmpty) continue;
      spans.add(
        TextSpan(
          text: partes[i],
          style: TextStyle(
            fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      style: tema.textTheme.bodyMedium?.copyWith(
        color: AppColores.texto,
        height: 1.4,
      ),
    );
  }
}
