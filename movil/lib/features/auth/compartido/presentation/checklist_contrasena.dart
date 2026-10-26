import 'package:flutter/material.dart';

import '../../../../core/tema/app_tema.dart';
import '../../registro/domain/validadores_registro.dart';

/// Reglas de la contraseña que se marcan mientras se escribe.
///
/// Usa las mismas reglas que el registro (RF-03 CA-4), como pide RF-06 CA-5.
/// Escucha solo al controlador de la contraseña, así no reconstruye todo el
/// formulario en cada tecla.
class ChecklistContrasena extends StatelessWidget {
  const ChecklistContrasena({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, valor, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final regla
              in ValidadoresRegistro.reglasContrasena(valor.text).entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    regla.value
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: regla.value
                        ? AppColores.primario
                        : AppColores.sobreAtenuado,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      regla.key,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColores.texto,
                        fontWeight:
                            regla.value ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
