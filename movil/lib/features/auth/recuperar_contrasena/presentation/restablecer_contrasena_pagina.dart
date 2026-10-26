import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../compartido/presentation/checklist_contrasena.dart';
import '../../compartido/presentation/fondo_auth.dart';
import '../../registro/domain/validadores_registro.dart';
import '../data/recuperar_contrasena_repositorio.dart';
import 'restablecer_contrasena_vista_modelo.dart';

/// Pantalla "Restablecer contraseña" del RF-06 (diseño de Figma).
///
/// Se abre sola al tocar el enlace del correo (ver `EstadoRecuperacion`).
/// Al terminar o cancelar se cierra la sesión temporal y el router lleva al
/// inicio de sesión.
class RestablecerContrasenaPagina extends ConsumerStatefulWidget {
  const RestablecerContrasenaPagina({super.key});

  @override
  ConsumerState<RestablecerContrasenaPagina> createState() =>
      _RestablecerContrasenaPaginaState();
}

class _RestablecerContrasenaPaginaState
    extends ConsumerState<RestablecerContrasenaPagina> {
  final _formKey = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  final _confirmar = TextEditingController();
  final _focoConfirmar = FocusNode();

  bool _ocultar = true;

  // Deja espacio bajo el campo para que el teclado no tape los botones.
  static const _espacioTeclado = EdgeInsets.fromLTRB(20, 20, 20, 180);

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    // El mensaje se muestra con el ScaffoldMessenger de la app, que sigue
    // vivo cuando el router cambia a la pantalla de inicio de sesión.
    final mensajero = ScaffoldMessenger.of(context);
    final cambio = await ref
        .read(restablecerContrasenaVistaModeloProvider.notifier)
        .restablecer(_contrasena.text);

    if (cambio) {
      // CA-6: el router ya lleva al login porque se cerró la sesión.
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
    }
  }

  void _mostrarAviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(restablecerContrasenaVistaModeloProvider);
    final cargando = estado.cargando;
    final textos = Theme.of(context).textTheme;

    ref.listen(restablecerContrasenaVistaModeloProvider, (_, nuevo) {
      switch (nuevo.error) {
        case ErrorRecuperacion.mismaContrasena:
          _mostrarAviso('La nueva contraseña debe ser distinta a la anterior');
        case ErrorRecuperacion.contrasenaDebil:
          _mostrarAviso('La contraseña no cumple las reglas');
        case ErrorRecuperacion.sesionVencida:
          // El enlace dejó de servir mientras escribía: se descarta y el
          // router lleva al login.
          _mostrarAviso('Este enlace ya no es válido. Solicita uno nuevo');
          ref.read(restablecerContrasenaVistaModeloProvider.notifier).cancelar();
        case ErrorRecuperacion.sinConexion:
          _mostrarAviso('Sin conexión. Revisa tu internet e intenta de nuevo');
        case ErrorRecuperacion.servidor ||
              ErrorRecuperacion.demasiadasSolicitudes:
          _mostrarAviso('Algo salió mal, intenta más tarde');
        case null:
          break;
      }
    });

    final ojo = IconButton(
      tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
      icon: Icon(
        _ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: cargando ? null : () => setState(() => _ocultar = !_ocultar),
    );

    return FondoAuth(
      tarjeta: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Restablecer contraseña',
              textAlign: TextAlign.center,
              style: textos.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            // CA-5: mismas reglas visuales que el registro (RF-03).
            CampoConEtiqueta(
              etiqueta: 'Nueva contraseña',
              child: TextFormField(
                controller: _contrasena,
                enabled: !cargando,
                obscureText: _ocultar,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                scrollPadding: _espacioTeclado,
                decoration: InputDecoration(hintText: 'Contraseña', suffixIcon: ojo),
                validator: ValidadoresRegistro.contrasena,
                onFieldSubmitted: (_) => _focoConfirmar.requestFocus(),
              ),
            ),
            ChecklistContrasena(controller: _contrasena),
            const SizedBox(height: 16),
            CampoConEtiqueta(
              etiqueta: 'Confirmar contraseña',
              child: TextFormField(
                controller: _confirmar,
                focusNode: _focoConfirmar,
                enabled: !cargando,
                obscureText: _ocultar,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                scrollPadding: _espacioTeclado,
                decoration:
                    const InputDecoration(hintText: 'Confirmar contraseña'),
                validator: (v) =>
                    ValidadoresRegistro.confirmarContrasena(v, _contrasena.text),
                onFieldSubmitted: (_) => _enviar(),
              ),
            ),
            Row(
              children: [
                EnlaceAuth(
                  texto: 'Cancelar',
                  secundario: true,
                  onPressed: cargando
                      ? null
                      : () => ref
                          .read(restablecerContrasenaVistaModeloProvider.notifier)
                          .cancelar(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotonConLogo(
                    texto: 'Restablecer',
                    logoAntes: true,
                    cargando: cargando,
                    onPressed: _enviar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contrasena.dispose();
    _confirmar.dispose();
    _focoConfirmar.dispose();
    super.dispose();
  }
}
