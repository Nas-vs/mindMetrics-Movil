import 'package:flutter/material.dart';

import '../../../../auth/registro/domain/validadores_registro.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/hamburger_button.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Vista de la sección de Perfil / Usuario (RF-23).
class ProfileView extends StatelessWidget {
  final ProfileViewModel viewModel;

  const ProfileView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Botón de menú hamburguesa
              HamburgerButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),

              const SizedBox(height: 16),

              // Contenido principal según el estado
              if (viewModel.cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryTeal,
                    ),
                  ),
                )
              else if (viewModel.perfil == null)
                _ErrorCargaPerfil(onReintentar: viewModel.cargarPerfil)
              else
                _ContenidoPerfil(viewModel: viewModel),

              // Espacio inferior para no chocar con la barra de navegación
              const SizedBox(height: 120),
            ],
          ),
        );
      },
    );
  }
}

/// CA-1: Muestra avatar con iniciales, nombre, @nickname, correo y fecha de registro.
class _ContenidoPerfil extends StatelessWidget {
  const _ContenidoPerfil({required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Column(
            children: [
              // Avatar circular con iniciales (CA-1)
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryTeal,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  viewModel.iniciales,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Nombre completo
              Text(
                viewModel.userName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 4),

              // @nickname
              Text(
                '@${viewModel.nickname}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Tarjeta con información detallada (CA-1)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardSolid,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              _ElementoDetalle(
                icono: Icons.mail_outline_rounded,
                etiqueta: 'Correo electrónico',
                valor: viewModel.email,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Colors.black12),
              ),
              _ElementoDetalle(
                icono: Icons.calendar_month_outlined,
                etiqueta: 'Fecha de registro',
                valor: viewModel.fechaRegistro,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // CA-2: Botón para editar el perfil
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            label: const Text(
              'Editar perfil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: () => _abrirHojaEdicion(context, viewModel),
          ),
        ),
      ],
    );
  }

  void _abrirHojaEdicion(BuildContext context, ProfileViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaEditarPerfil(viewModel: vm),
    );
  }
}

class _ElementoDetalle extends StatelessWidget {
  const _ElementoDetalle({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: AppColors.primaryTeal, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// CA-2: Formulario modal para cambiar nombre y nickname.
class _HojaEditarPerfil extends StatefulWidget {
  const _HojaEditarPerfil({required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  State<_HojaEditarPerfil> createState() => _HojaEditarPerfilState();
}

class _HojaEditarPerfilState extends State<_HojaEditarPerfil> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _nicknameCtrl;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.viewModel.userName);
    _nicknameCtrl = TextEditingController(text: widget.viewModel.nickname);
    widget.viewModel.limpiarError();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final exito = await widget.viewModel.actualizarPerfil(
      nuevoNombre: _nombreCtrl.text,
      nuevoNickname: _nicknameCtrl.text,
    );

    if (exito && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente.'),
          backgroundColor: AppColors.primaryTeal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fondoTeclado = MediaQuery.of(context).viewInsets.bottom;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final guardando = widget.viewModel.guardando;
        final error = widget.viewModel.error;

        return Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, fondoTeclado + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Editar perfil',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),

                // Campo Nombre completo
                TextFormField(
                  controller: _nombreCtrl,
                  enabled: !guardando,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: ValidadoresRegistro.nombreCompleto,
                ),
                const SizedBox(height: 14),

                // Campo Nickname
                TextFormField(
                  controller: _nicknameCtrl,
                  enabled: !guardando,
                  decoration: const InputDecoration(
                    labelText: 'Nickname',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: ValidadoresRegistro.nickname,
                ),

                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 24),

                // Botones Guardar y Cancelar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: guardando
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                        ),
                        onPressed: guardando ? null : _guardar,
                        child: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorCargaPerfil extends StatelessWidget {
  const _ErrorCargaPerfil({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar tu perfil.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
              ),
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
