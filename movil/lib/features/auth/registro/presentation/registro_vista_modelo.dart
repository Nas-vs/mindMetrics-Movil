import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/registro_repositorio.dart';
import '../domain/datos_registro.dart';
import 'registro_estado.dart';

/// ViewModel (MVVM): recibe la intención de la vista, llama al repositorio
/// y expone un estado que la vista solo dibuja.
class RegistroVistaModelo extends Notifier<RegistroEstado> {
  @override
  RegistroEstado build() => const RegistroEstado();

  Future<void> registrar(DatosRegistro datos) async {
    if (state.cargando) return; // Evita el doble envío (CA-7).

    state = const RegistroEstado(cargando: true);
    try {
      await ref.read(registroRepositorioProvider).registrar(datos);
      if (!ref.mounted) return; // La pantalla se cerró mientras esperaba.
      state = const RegistroEstado(exito: true);
    } on RegistroExcepcion catch (e) {
      if (!ref.mounted) return;
      state = RegistroEstado(error: e.tipo);
    }
  }
}

/// autoDispose: el estado se descarta al salir de la pantalla.
final registroVistaModeloProvider =
    NotifierProvider.autoDispose<RegistroVistaModelo, RegistroEstado>(
  RegistroVistaModelo.new,
);
