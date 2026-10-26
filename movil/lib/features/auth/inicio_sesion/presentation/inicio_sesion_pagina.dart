import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/rutas.dart';
import '../../../../core/tema/app_tema.dart';
import '../../compartido/presentation/fondo_auth.dart';
import '../../verificacion/domain/argumentos_verificacion.dart';
import '../data/inicio_sesion_repositorio.dart';
import 'inicio_sesion_estado.dart';
import 'inicio_sesion_vista_modelo.dart';

/// Pantalla del RF-04 (diseño "Sign In" de Figma).
class InicioSesionPagina extends ConsumerStatefulWidget {
  const InicioSesionPagina({
    super.key,
    this.mensajeInicial,
    this.onOlvidoContrasena,
  });

  /// Aviso que se muestra al llegar, p. ej. desde RF-05 CA-7:
  /// "Por seguridad, vuelve a iniciar sesión".
  final String? mensajeInicial;

  /// Navegación a RF-06. Mientras no exista, el enlace se desactiva.
  final VoidCallback? onOlvidoContrasena;

  @override
  ConsumerState<InicioSesionPagina> createState() => _InicioSesionPaginaState();
}

class _InicioSesionPaginaState extends ConsumerState<InicioSesionPagina> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _focoContrasena = FocusNode();

  bool _ocultarContrasena = true;

  /// Error que se muestra dentro de la tarjeta (CA-6 y CA-7).
  String? _errorFormulario;

  // Deja espacio bajo el campo para que el teclado no tape el botón.
  static const _espacioTeclado = EdgeInsets.fromLTRB(20, 20, 20, 180);

  @override
  void initState() {
    super.initState();
    final mensaje = widget.mensajeInicial;
    if (mensaje != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mostrarAviso(mensaje);
      });
    }
  }

  bool get _camposLlenos =>
      _correo.text.trim().isNotEmpty && _contrasena.text.isNotEmpty;

  Future<void> _enviar() async {
    if (!_camposLlenos) return;
    FocusScope.of(context).unfocus();
    setState(() => _errorFormulario = null);
    await ref
        .read(inicioSesionVistaModeloProvider.notifier)
        .iniciarSesion(correo: _correo.text, contrasena: _contrasena.text);
  }

  void _mostrarAviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _alCambiarEstado(InicioSesionEstado? _, InicioSesionEstado nuevo) {
    final correo = _correo.text.trim().toLowerCase();

    switch (nuevo.resultado) {
      case ResultadoInicioSesion.sesionIniciada:
        // CA-4: celular conocido. `go` reemplaza la pila.
        context.go(Rutas.inicio);
        return;
      case ResultadoInicioSesion.requiereCodigo:
        // CA-5: celular nuevo → código de RF-05.
        context.go(
          Rutas.verificacion,
          extra: ArgumentosVerificacion(
            correo: correo,
            motivo: MotivoVerificacion.inicioSesion,
          ),
        );
        return;
      case ResultadoInicioSesion.requiereVerificarCorreo:
        context.go(
          Rutas.verificacion,
          extra: ArgumentosVerificacion(
            correo: correo,
            motivo: MotivoVerificacion.registro,
          ),
        );
        return;
      case null:
        break;
    }

    switch (nuevo.error) {
      case ErrorInicioSesion.credencialesInvalidas:
        // CA-6: mensaje genérico (no dice cuál falló) y se limpia la contraseña.
        _contrasena.clear();
        setState(() => _errorFormulario = 'Correo o contraseña incorrectos');
        _focoContrasena.requestFocus();
      case ErrorInicioSesion.bloqueado:
        // CA-7
        _contrasena.clear();
        setState(
          () => _errorFormulario =
              'Demasiados intentos. Intenta de nuevo en 15 minutos',
        );
      case ErrorInicioSesion.demasiadosCorreos:
        _mostrarAviso(
          'Ya te enviamos un código hace poco. Espera un momento e intenta de nuevo',
        );
      case ErrorInicioSesion.sinConexion:
        _mostrarAviso('Necesitas internet para iniciar sesión');
      case ErrorInicioSesion.servidor:
        _mostrarAviso('Algo salió mal, intenta más tarde');
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(inicioSesionVistaModeloProvider);
    ref.listen(inicioSesionVistaModeloProvider, _alCambiarEstado);

    final cargando = estado.cargando;

    return FondoAuth(
      pie: _EnlaceRegistro(
        onTap: cargando ? null : () => context.go(Rutas.consentimiento),
      ),
      tarjeta: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoConEtiqueta(
              etiqueta: 'Correo electrónico',
              child: TextField(
                controller: _correo,
                enabled: !cargando, // CA-3: controles bloqueados
                decoration: const InputDecoration(
                  hintText: 'correo@dominio.com',
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                scrollPadding: _espacioTeclado,
                onChanged: (_) => setState(() => _errorFormulario = null),
                onSubmitted: (_) => _focoContrasena.requestFocus(),
              ),
            ),
            CampoConEtiqueta(
              etiqueta: 'Contraseña',
              child: TextField(
                controller: _contrasena,
                focusNode: _focoContrasena,
                enabled: !cargando,
                obscureText: _ocultarContrasena,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                scrollPadding: _espacioTeclado,
                onChanged: (_) => setState(() => _errorFormulario = null),
                onSubmitted: (_) => _enviar(),
                decoration: InputDecoration(
                  hintText: '•••••',
                  suffixIcon: IconButton(
                    // CA-1: mostrar / ocultar.
                    tooltip: _ocultarContrasena
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    icon: Icon(
                      _ocultarContrasena
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: cargando
                        ? null
                        : () => setState(
                            () => _ocultarContrasena = !_ocultarContrasena,
                          ),
                  ),
                ),
              ),
            ),
            if (_errorFormulario != null) ...[
              _MensajeError(texto: _errorFormulario!),
              const SizedBox(height: 12),
            ],
            // CA-2: deshabilitado mientras algún campo esté vacío.
            BotonConLogo(
              texto: 'Iniciar sesión',
              cargando: cargando,
              onPressed: _camposLlenos ? _enviar : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: EnlaceAuth(
                texto: '¿Olvidó su contraseña?',
                onPressed: cargando ? null : widget.onOlvidoContrasena,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _focoContrasena.dispose();
    super.dispose();
  }
}

/// Error en rojo con ícono y texto (no solo color), como pide RF-03 CA-5.
class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: AppColores.destructivo,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColores.destructivo,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "¿No tienes cuenta? Regístrate aquí" al final de la pantalla.
class _EnlaceRegistro extends StatelessWidget {
  const _EnlaceRegistro({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          '¿No tienes cuenta?',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColores.primario,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(48, 48),
          ),
          child: const Text(
            'Regístrate aquí',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
