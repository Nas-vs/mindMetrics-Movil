import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/rutas.dart';
import '../../../../core/tema/app_tema.dart';
import '../../compartido/presentation/fondo_auth.dart';
import '../data/verificacion_repositorio.dart';
import '../domain/argumentos_verificacion.dart';
import 'verificacion_estado.dart';
import 'verificacion_vista_modelo.dart';

/// Pantalla del RF-05 (diseño "2FA" de Figma).
class VerificacionPagina extends ConsumerStatefulWidget {
  const VerificacionPagina({super.key, required this.argumentos});

  final ArgumentosVerificacion argumentos;

  @override
  ConsumerState<VerificacionPagina> createState() => _VerificacionPaginaState();
}

class _VerificacionPaginaState extends ConsumerState<VerificacionPagina>
    with SingleTickerProviderStateMixin {
  final _codigo = TextEditingController();
  final _foco = FocusNode();

  // CA-6: animación de sacudida al equivocarse.
  late final _sacudida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool _mostrarErrorCasillas = false;

  VerificacionVistaModelo get _vm =>
      ref.read(verificacionVistaModeloProvider.notifier);

  void _alEscribir(String valor) {
    // Repinta el botón y quita el error al volver a escribir.
    setState(() => _mostrarErrorCasillas = false);
    // CA-4: al completar el sexto dígito se valida sola.
    if (valor.length == 6) _verificar();
  }

  void _verificar() => _vm.verificar(widget.argumentos, _codigo.text);

  void _mostrarAviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _alCambiarEstado(VerificacionEstado? anterior, VerificacionEstado nuevo) {
    if (nuevo.exito) {
      // CA-8: `go` reemplaza la pila; "Atrás" no vuelve al código.
      context.go(Rutas.inicio);
      return;
    }

    if (nuevo.descartada) {
      // CA-7: no hay tokens que borrar, porque la sesión solo se crea al
      // verificar el código; se vuelve al inicio de sesión con el aviso.
      context.go(
        Rutas.login,
        extra: 'Por seguridad, vuelve a iniciar sesión',
      );
      return;
    }

    final fallosAntes = anterior?.intentosFallidos ?? 0;
    if (nuevo.intentosFallidos > fallosAntes) {
      // CA-6: vibra, se limpian las casillas y se avisa cuántos quedan.
      HapticFeedback.mediumImpact();
      _sacudida.forward(from: 0);
      _codigo.clear();
      setState(() => _mostrarErrorCasillas = true);
      _foco.requestFocus();
    }

    final reenviosAntes = anterior?.reenviosUsados ?? 0;
    if (nuevo.reenviosUsados > reenviosAntes) {
      _codigo.clear();
      setState(() => _mostrarErrorCasillas = false);
      _mostrarAviso('Te enviamos un código nuevo');
    }

    switch (nuevo.error) {
      case ErrorVerificacion.sinConexion:
        _mostrarAviso('Sin conexión, intenta de nuevo');
      case ErrorVerificacion.demasiadosCorreos:
        _mostrarAviso('Espera un momento antes de pedir otro código');
      case ErrorVerificacion.servidor:
        _mostrarAviso('Algo salió mal, intenta más tarde');
      case ErrorVerificacion.codigoIncorrecto:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(verificacionVistaModeloProvider);
    ref.listen(verificacionVistaModeloProvider, _alCambiarEstado);

    final textos = Theme.of(context).textTheme;
    final esRegistro = widget.argumentos.motivo == MotivoVerificacion.registro;
    final restantes =
        VerificacionVistaModelo.maxIntentos - estado.intentosFallidos;

    return FondoAuth(
      tarjeta: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            esRegistro ? 'Verifica tu correo' : 'Verificación en 2 pasos',
            textAlign: TextAlign.center,
            style: textos.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          // CA-2: correo enmascarado.
          Text(
            'Ingresa el código de 6 dígitos que enviamos a '
            '${enmascararCorreo(widget.argumentos.correo)}',
            textAlign: TextAlign.center,
            style: textos.bodyLarge?.copyWith(color: AppColores.texto),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _sacudida,
            builder: (context, child) {
              final t = _sacudida.value;
              final desplazamiento = math.sin(t * math.pi * 6) * 12 * (1 - t);
              return Transform.translate(
                offset: Offset(desplazamiento, 0),
                child: child,
              );
            },
            child: _CampoCodigo(
              controller: _codigo,
              focusNode: _foco,
              habilitado: !estado.cargando,
              conError: _mostrarErrorCasillas,
              onChanged: _alEscribir,
            ),
          ),
          if (_mostrarErrorCasillas && restantes > 0) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                'Código incorrecto. '
                '${restantes == 1 ? 'Te queda 1 intento' : 'Te quedan $restantes intentos'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColores.destructivo,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220),
              child: BotonConLogo(
                texto: 'Verificar código',
                logoAntes: true,
                cargando: estado.cargando,
                onPressed: _codigo.text.length == 6 ? _verificar : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _Reenviar(estado: estado, vm: _vm, argumentos: widget.argumentos)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codigo.dispose();
    _foco.dispose();
    _sacudida.dispose();
    super.dispose();
  }
}

/// CA-5: "Reenviar en 00:59" → "Reenviar código", máximo 3 veces.
class _Reenviar extends StatelessWidget {
  const _Reenviar({
    required this.estado,
    required this.vm,
    required this.argumentos,
  });

  final VerificacionEstado estado;
  final VerificacionVistaModelo vm;
  final ArgumentosVerificacion argumentos;

  @override
  Widget build(BuildContext context) {
    if (estado.reenviosUsados >= VerificacionVistaModelo.maxReenvios) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'Ya no puedes pedir más códigos',
          style: TextStyle(color: AppColores.sobreAtenuado, fontSize: 14),
        ),
      );
    }

    final segundos = estado.segundosParaReenviar;
    final texto = segundos > 0
        ? 'Reenviar en 00:${segundos.toString().padLeft(2, '0')}'
        : 'Reenviar código';

    return EnlaceAuth(
      texto: texto,
      onPressed: vm.puedeReenviar ? () => vm.reenviar(argumentos) : null,
    );
  }
}

/// Seis casillas para el código (CA-2 y CA-3).
///
/// Por debajo es UN solo campo de texto invisible encima de las casillas:
/// así funcionan el teclado numérico, pegar el código completo y el
/// autocompletado del código que ofrece el teclado.
class _CampoCodigo extends StatelessWidget {
  const _CampoCodigo({
    required this.controller,
    required this.focusNode,
    required this.habilitado,
    required this.conError,
    required this.onChanged,
  });

  static const _largo = 6;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool habilitado;
  final bool conError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Código de verificación de 6 dígitos',
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final texto = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < _largo; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Casilla(
                        digito: i < texto.length ? texto[i] : '',
                        activa: focusNode.hasFocus &&
                            (i == texto.length ||
                                (texto.length == _largo && i == _largo - 1)),
                        conError: conError,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: habilitado,
              autofocus: true, // CA-3: abre el teclado al entrar
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_largo),
              ],
              onChanged: onChanged,
              showCursor: false,
              enableSuggestions: false,
              autocorrect: false,
              // Texto y fondo invisibles: solo se ven las casillas.
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.digito,
    required this.activa,
    required this.conError,
  });

  final String digito;
  final bool activa;
  final bool conError;

  @override
  Widget build(BuildContext context) {
    final colorBorde = conError
        ? AppColores.destructivo
        : activa
            ? AppColores.primario
            : Colors.transparent;

    return AspectRatio(
      aspectRatio: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColores.campo,
          borderRadius: BorderRadius.circular(AppMedidas.radio),
          border: Border.all(color: colorBorde, width: 1.5),
        ),
        child: Text(
          digito,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColores.texto,
          ),
        ),
      ),
    );
  }
}
