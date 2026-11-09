import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recordatorio_servicio.dart';
import 'beneficio_recordatorio_hoja.dart';
import 'recordatorio_vista_modelo.dart';

/// RF-22: configurar el recordatorio diario (activar y elegir la hora).
class RecordatorioPagina extends ConsumerStatefulWidget {
  const RecordatorioPagina({super.key});

  @override
  ConsumerState<RecordatorioPagina> createState() => _RecordatorioPaginaState();
}

class _RecordatorioPaginaState extends ConsumerState<RecordatorioPagina> {
  late final RecordatorioVistaModelo _vm =
      RecordatorioVistaModelo(ref.read(recordatorioServicioProvider))
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

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _vm.preferencias.hora,
        minute: _vm.preferencias.minuto,
      ),
      helpText: 'Hora del recordatorio',
    );
    if (elegida != null) await _vm.cambiarHora(elegida.hour, elegida.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorio diario')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          final prefs = _vm.preferencias;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Recordarme registrar mi día'),
                subtitle: const Text(
                  'Si ya registraste cómo te sientes, ese día no te avisamos.',
                ),
                value: prefs.activo,
                onChanged: _vm.ocupado ? null : _vm.cambiarActivo,
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Hora del recordatorio'),
                subtitle: Text(prefs.horaTexto),
                enabled: prefs.activo && !_vm.ocupado,
                onTap: _elegirHora,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Probar notificación'),
                  onPressed: prefs.activo && !_vm.ocupado ? _vm.probar : null,
                ),
              ),
              // Solo en modo desarrollo: prueba CA-1 sin la pantalla de RF-08.
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    onPressed: _vm.ocupado
                        ? null
                        : () => _vm.simularRegistro(
                              () => mostrarBeneficioRecordatorio(context),
                            ),
                    child: const Text('[Prueba] Simular registro de ánimo'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
