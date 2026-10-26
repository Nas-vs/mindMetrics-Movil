import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/rutas.dart';
import '../../../../core/tema/app_tema.dart';
import '../../compartido/presentation/fondo_auth.dart';
import '../../registro/domain/validadores_registro.dart';
import '../data/recuperar_contrasena_repositorio.dart';
import 'recuperar_contrasena_vista_modelo.dart';

/// Pantalla "Recupera tu contraseña" del RF-06 (diseño de Figma).
class RecuperarContrasenaPagina extends ConsumerStatefulWidget {
  const RecuperarContrasenaPagina({
    super.key,
    this.enlaceInvalido = false,
    this.onAvisoMostrado,
  });

  /// CA-7: se llegó aquí porque el enlace del correo venció o ya se usó.
  final bool enlaceInvalido;

  /// Avisa al router que el aviso de enlace inválido ya se mostró.
  final VoidCallback? onAvisoMostrado;

  @override
  ConsumerState<RecuperarContrasenaPagina> createState() =>
      _RecuperarContrasenaPaginaState();
}

class _RecuperarContrasenaPaginaState
    extends ConsumerState<RecuperarContrasenaPagina> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();

  /// Se guarda aquí porque el router limpia su bandera al mostrarla.
  bool _enlaceInvalido = false;

  @override
  void initState() {
    super.initState();
    _revisarEnlaceInvalido();
  }

  @override
  void didUpdateWidget(RecuperarContrasenaPagina anterior) {
    super.didUpdateWidget(anterior);
    // El enlace inválido puede llegar estando ya en esta pantalla.
    if (widget.enlaceInvalido && !anterior.enlaceInvalido) {
      _revisarEnlaceInvalido();
    }
  }

  void _revisarEnlaceInvalido() {
    if (!widget.enlaceInvalido) return;
    _enlaceInvalido = true;
    // Se avisa después del frame: notificar al router durante el build no
    // está permitido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      widget.onAvisoMostrado?.call();
    });
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(recuperarContrasenaVistaModeloProvider.notifier)
        .solicitarEnlace(_correo.text);
    if (mounted) setState(() => _enlaceInvalido = false);
  }

  void _mostrarAviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recuperarContrasenaVistaModeloProvider);
    final textos = Theme.of(context).textTheme;

    ref.listen(recuperarContrasenaVistaModeloProvider, (_, nuevo) {
      switch (nuevo.error) {
        case ErrorRecuperacion.demasiadasSolicitudes:
          _mostrarAviso(
            'Ya te enviamos un enlace hace poco. Espera un momento e intenta de nuevo',
          );
        case ErrorRecuperacion.sinConexion:
          _mostrarAviso('Sin conexión. Revisa tu internet e intenta de nuevo');
        case ErrorRecuperacion.servidor ||
              ErrorRecuperacion.mismaContrasena ||
              ErrorRecuperacion.contrasenaDebil ||
              ErrorRecuperacion.sesionVencida:
          _mostrarAviso('Algo salió mal, intenta más tarde');
        case null:
          break;
      }
    });

    return FondoAuth(
      tarjeta: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_enlaceInvalido) ...[
              // CA-7
              const _AvisoEnlaceInvalido(),
              const SizedBox(height: 16),
            ],
            Text(
              'Recupera tu contraseña',
              textAlign: TextAlign.center,
              style: textos.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el correo electrónico vinculado a tu cuenta',
              textAlign: TextAlign.center,
              style: textos.bodyLarge?.copyWith(color: AppColores.texto),
            ),
            const SizedBox(height: 24),
            // CA-1
            CampoConEtiqueta(
              etiqueta: 'Correo electrónico',
              child: TextFormField(
                controller: _correo,
                enabled: !estado.cargando,
                decoration:
                    const InputDecoration(hintText: 'correo@dominio.com'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.send,
                autofillHints: const [AutofillHints.email],
                validator: ValidadoresRegistro.correo,
                onFieldSubmitted: (_) => _enviar(),
              ),
            ),
            Row(
              children: [
                EnlaceAuth(
                  texto: 'Cancelar',
                  secundario: true,
                  onPressed:
                      estado.cargando ? null : () => context.go(Rutas.login),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotonConLogo(
                    texto: _enlaceInvalido ? 'Solicitar uno nuevo' : 'Restablecer',
                    logoAntes: true,
                    cargando: estado.cargando,
                    onPressed: _enviar,
                  ),
                ),
              ],
            ),
            if (estado.enviado) ...[
              const SizedBox(height: 20),
              // CA-2: el mismo mensaje exista o no la cuenta.
              Semantics(
                liveRegion: true,
                child: Text(
                  'Si el correo está registrado, recibirás un enlace en unos minutos',
                  textAlign: TextAlign.center,
                  style: textos.bodyLarge?.copyWith(color: Colors.black),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }
}

/// CA-7: "Este enlace ya no es válido".
class _AvisoEnlaceInvalido extends StatelessWidget {
  const _AvisoEnlaceInvalido();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColores.destructivo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppMedidas.radio),
          border: Border.all(color: AppColores.destructivo.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.link_off, size: 20, color: AppColores.destructivo),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Este enlace ya no es válido. Solicita uno nuevo.',
                style: TextStyle(color: AppColores.destructivo, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
