import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consentimiento_repositorio.dart';
import 'consentimiento_estado.dart';

/// ViewModel (MVVM) del RF-02: carga la política vigente al abrir la pantalla.
class ConsentimientoVistaModelo extends Notifier<ConsentimientoEstado> {
  @override
  ConsentimientoEstado build() {
    Future.microtask(cargar);
    return const ConsentimientoEstado(cargando: true);
  }

  Future<void> cargar() async {
    state = const ConsentimientoEstado(cargando: true);
    try {
      final politica = await ref
          .read(consentimientoRepositorioProvider)
          .obtenerPoliticaVigente();
      if (!ref.mounted) return;
      state = ConsentimientoEstado(politica: politica);
    } on ConsentimientoExcepcion catch (e) {
      if (!ref.mounted) return;
      state = ConsentimientoEstado(error: e.tipo);
    }
  }
}

final consentimientoVistaModeloProvider =
    NotifierProvider.autoDispose<
      ConsentimientoVistaModelo,
      ConsentimientoEstado
    >(ConsentimientoVistaModelo.new);
