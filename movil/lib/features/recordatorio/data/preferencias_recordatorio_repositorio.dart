import 'dart:convert';

import '../domain/preferencias_recordatorio.dart';
import 'almacen_clave_valor.dart';

/// Guarda y lee la configuración del recordatorio (RF-22).
///
/// TODO(RF-22 Back, Samuel): cuando exista la tabla en Supabase, guardar
/// también allá (así la preferencia sobrevive a reinstalar la app). La
/// pantalla y el servicio no cambian: solo este archivo.
class PreferenciasRecordatorioRepositorio {
  PreferenciasRecordatorioRepositorio(this._almacen);

  final AlmacenClaveValor _almacen;

  static const _clave = 'rf22_preferencias_recordatorio';

  Future<PreferenciasRecordatorio> leer() async {
    final texto = await _almacen.leer(_clave);
    if (texto == null || texto.isEmpty) return const PreferenciasRecordatorio();
    try {
      return PreferenciasRecordatorio.fromJson(
        jsonDecode(texto) as Map<String, dynamic>,
      );
    } on FormatException {
      return const PreferenciasRecordatorio();
    }
  }

  Future<void> guardar(PreferenciasRecordatorio preferencias) =>
      _almacen.escribir(_clave, jsonEncode(preferencias.toJson()));
}
