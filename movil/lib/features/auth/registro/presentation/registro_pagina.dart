import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/tema/app_tema.dart';
import '../data/registro_repositorio.dart';
import '../domain/datos_registro.dart';
import '../domain/validadores_registro.dart';
import 'registro_vista_modelo.dart';

/// Pantalla del RF-03. Recibe la versión del consentimiento aceptado en RF-02.
///
/// Ruta sugerida:
///   GoRoute(
///     path: '/registro',
///     builder: (_, s) => RegistroPagina(versionPolitica: s.extra! as String),
///   )
class RegistroPagina extends ConsumerStatefulWidget {
  const RegistroPagina({
    super.key,
    required this.versionPolitica,
    this.onIniciarSesion,
  });

  final String versionPolitica;

  /// Navegación al login (RF-04). Mientras no exista, el enlace se desactiva.
  final VoidCallback? onIniciarSesion;

  @override
  ConsumerState<RegistroPagina> createState() => _RegistroPaginaState();
}

class _RegistroPaginaState extends ConsumerState<RegistroPagina> {
  static const _rutaFondo = 'assets/images/fondo_registro_movil.jpg';
  static const _rutaLogo = 'assets/images/logo_mindmetrics_blanco.png';

  final _formKey = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _nickname = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmar = TextEditingController();
  final _fechaTexto = TextEditingController();

  DateTime? _fechaNacimiento;
  bool _ocultarContrasena = true;

  // Una llave y un foco por campo, en el orden visual (CA-6).
  static const _numCampos = 6;
  final _llaves = List.generate(_numCampos, (_) => GlobalKey());
  final _focos = List.generate(_numCampos, (_) => FocusNode());

  /// Validaciones en el mismo orden que los campos en pantalla.
  List<String? Function()> get _validaciones => [
        () => ValidadoresRegistro.nombreCompleto(_nombre.text),
        () => ValidadoresRegistro.nickname(_nickname.text),
        () => ValidadoresRegistro.correo(_correo.text),
        () => ValidadoresRegistro.fechaNacimiento(_fechaNacimiento),
        () => ValidadoresRegistro.contrasena(_contrasena.text),
        () => ValidadoresRegistro.confirmarContrasena(
              _confirmar.text,
              _contrasena.text,
            ),
      ];

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    _formKey.currentState!.validate(); // Pinta los errores en todos (CA-5).

    final primerError = _validaciones.indexWhere((v) => v() != null);
    if (primerError != -1) {
      // CA-6: scroll y foco al primer campo con error; no se llama a la API.
      final contexto = _llaves[primerError].currentContext;
      if (contexto != null) {
        await Scrollable.ensureVisible(
          contexto,
          duration: const Duration(milliseconds: 300),
          alignment: 0.2,
        );
      }
      _focos[primerError].requestFocus();
      return;
    }

    await ref.read(registroVistaModeloProvider.notifier).registrar(
          DatosRegistro(
            nombreCompleto: _nombre.text,
            nickname: _nickname.text,
            correo: _correo.text,
            contrasena: _contrasena.text,
            fechaNacimiento: _fechaNacimiento!,
            versionPolitica: widget.versionPolitica,
          ),
        );
  }

  Future<void> _elegirFecha() async {
    final limite = ValidadoresRegistro.fechaLimite();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? limite,
      firstDate: DateTime(1900),
      lastDate: limite, // Imposible elegir a un menor; el validador es la 2.ª barrera.
      helpText: 'Fecha de nacimiento',
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _fechaNacimiento = elegida;
      _fechaTexto.text =
          MaterialLocalizations.of(context).formatMediumDate(elegida);
    });
    _formKey.currentState?.validate();
  }

  String _mensaje(ErrorRegistro error) => switch (error) {
        ErrorRegistro.correoDuplicado => 'Ya existe una cuenta con ese correo',
        ErrorRegistro.nicknameDuplicado => 'Ese nickname ya está en uso',
        ErrorRegistro.sinConexion =>
          'Sin conexión. Revisa tu red e intenta de nuevo',
        ErrorRegistro.servidor => 'Ocurrió un error. Intenta más tarde',
      };

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(registroVistaModeloProvider);
    final textos = Theme.of(context).textTheme;

    ref.listen(registroVistaModeloProvider, (_, nuevo) {
      if (nuevo.exito) {
        // CA-8: `go` reemplaza la pila; "Atrás" no vuelve al formulario.
        context.go('/verificacion', extra: _correo.text.trim().toLowerCase());
      } else if (nuevo.error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_mensaje(nuevo.error!))));
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Fondo fijo: no se desplaza con el formulario.
          Positioned.fill(
            child: Image.asset(_rutaFondo, fit: BoxFit.cover),
          ),
          // Velo claro para que la tarjeta destaque sobre la imagen.
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.25)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                // CA-1: pantalla desplazable.
                padding: const EdgeInsets.all(AppMedidas.margenPantalla),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppMedidas.anchoMaximoFormulario,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppMedidas.relleno),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Crear cuenta',
                              style: textos.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Regístrate para comenzar tu seguimiento emocional',
                              style: textos.bodyLarge?.copyWith(
                                color: AppColores.sobreAtenuado,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _CampoConEtiqueta(
                              etiqueta: 'Nombre completo',
                              child: TextFormField(
                                key: _llaves[0],
                                focusNode: _focos[0],
                                controller: _nombre,
                                decoration: const InputDecoration(
                                  hintText: 'Nombre completo',
                                  counterText: '',
                                ),
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                maxLength: 60,
                                validator: ValidadoresRegistro.nombreCompleto,
                              ),
                            ),
                            _CampoConEtiqueta(
                              etiqueta: 'Nickname',
                              child: TextFormField(
                                key: _llaves[1],
                                focusNode: _focos[1],
                                controller: _nickname,
                                decoration: const InputDecoration(
                                  hintText: 'Cómo quieres que te llamemos',
                                  prefixText: '@',
                                  counterText: '',
                                ),
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                maxLength: 20,
                                validator: ValidadoresRegistro.nickname,
                              ),
                            ),
                            _CampoConEtiqueta(
                              etiqueta: 'Correo electrónico',
                              child: TextFormField(
                                key: _llaves[2],
                                focusNode: _focos[2],
                                controller: _correo,
                                decoration: const InputDecoration(
                                  hintText: 'nombre@correo.com',
                                ),
                                keyboardType: TextInputType.emailAddress, // CA-2
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                validator: ValidadoresRegistro.correo,
                              ),
                            ),
                            _CampoConEtiqueta(
                              etiqueta: 'Fecha de nacimiento',
                              child: TextFormField(
                                key: _llaves[3],
                                focusNode: _focos[3],
                                controller: _fechaTexto,
                                readOnly: true,
                                onTap: _elegirFecha,
                                decoration: const InputDecoration(
                                  hintText: 'Selecciona una fecha',
                                  suffixIcon:
                                      Icon(Icons.calendar_today_outlined, size: 20),
                                ),
                                validator: (_) => ValidadoresRegistro
                                    .fechaNacimiento(_fechaNacimiento),
                              ),
                            ),
                            _CampoConEtiqueta(
                              etiqueta: 'Contraseña',
                              child: TextFormField(
                                key: _llaves[4],
                                focusNode: _focos[4],
                                controller: _contrasena,
                                obscureText: _ocultarContrasena,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  suffixIcon: IconButton(
                                    // CA-3: mostrar / ocultar.
                                    tooltip: _ocultarContrasena
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    icon: Icon(_ocultarContrasena
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                                    onPressed: () => setState(
                                      () => _ocultarContrasena =
                                          !_ocultarContrasena,
                                    ),
                                  ),
                                ),
                                validator: ValidadoresRegistro.contrasena,
                              ),
                            ),
                            _ChecklistContrasena(controller: _contrasena), // CA-4
                            const SizedBox(height: 16),
                            _CampoConEtiqueta(
                              etiqueta: 'Confirmar contraseña',
                              child: TextFormField(
                                key: _llaves[5],
                                focusNode: _focos[5],
                                controller: _confirmar,
                                obscureText: _ocultarContrasena,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _enviar(),
                                decoration: const InputDecoration(
                                  hintText: 'Confirmar contraseña',
                                ),
                                validator: (v) => ValidadoresRegistro
                                    .confirmarContrasena(v, _contrasena.text),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              // CA-7: deshabilitado y con indicador mientras carga.
                              onPressed: estado.cargando ? null : _enviar,
                              child: estado.cargando
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColores.sobrePrimario,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          _rutaLogo,
                                          height: 32,
                                          excludeFromSemantics: true,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Regístrate'),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 16),
                            _EnlaceIniciarSesion(onTap: widget.onIniciarSesion),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _nickname,
      _correo,
      _contrasena,
      _confirmar,
      _fechaTexto,
    ]) {
      c.dispose();
    }
    for (final f in _focos) {
      f.dispose();
    }
    super.dispose();
  }
}

/// Etiqueta encima del campo, como en el diseño.
class _CampoConEtiqueta extends StatelessWidget {
  const _CampoConEtiqueta({required this.etiqueta, required this.child});
  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColores.texto,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// CA-4: reglas que se marcan en el color primario mientras se escribe.
/// Escucha solo al controlador de la contraseña, así no reconstruye todo
/// el formulario en cada tecla.
class _ChecklistContrasena extends StatelessWidget {
  const _ChecklistContrasena({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, valor, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColores.secundario,
          borderRadius: BorderRadius.circular(AppMedidas.radio),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final regla
                in ValidadoresRegistro.reglasContrasena(valor.text).entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      regla.value
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: regla.value
                          ? AppColores.primario
                          : AppColores.sobreAtenuado,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      regla.key,
                      style: TextStyle(
                        fontSize: 13,
                        color: regla.value
                            ? AppColores.texto
                            : AppColores.sobreSecundario,
                        fontWeight:
                            regla.value ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Ya tengo cuenta. Inicia sesión" — va dentro de la tarjeta porque sobre la
/// imagen de fondo el texto pierde contraste.
class _EnlaceIniciarSesion extends StatelessWidget {
  const _EnlaceIniciarSesion({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Ya tengo cuenta.', style: TextStyle(fontSize: 16)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColores.primario,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(48, 48), // área táctil mínima
          ),
          child: const Text(
            'Inicia sesión',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
