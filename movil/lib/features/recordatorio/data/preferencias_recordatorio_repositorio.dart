import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/preferencias_recordatorio.dart';
import 'almacen_clave_valor.dart';

/// Guarda y lee la configuración del recordatorio (RF-22).
///
/// Combina almacenamiento local (para funcionar sin conexión y que la alarma
/// siempre suene) con sincronización en Supabase (RF-22 Back, Samuel Orozco)
/// para que la configuración sobreviva a reinstalar la app o cambiar de celular.
class PreferenciasRecordatorioRepositorio {
  PreferenciasRecordatorioRepositorio(this._almacen, [SupabaseClient? cliente])
    : _cliente = cliente;

  final AlmacenClaveValor _almacen;
  final SupabaseClient? _cliente;

  SupabaseClient? get _supabase {
    if (_cliente != null) return _cliente;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static const _clave = 'rf22_preferencias_recordatorio';

  Future<PreferenciasRecordatorio> leer() async {
    // 1. Primero lee de local (inmediato y sin red).
    var preferencias = const PreferenciasRecordatorio();
    final texto = await _almacen.leer(_clave);
    if (texto != null && texto.isNotEmpty) {
      try {
        preferencias = PreferenciasRecordatorio.fromJson(
          jsonDecode(texto) as Map<String, dynamic>,
        );
      } on FormatException {
        // Formato corrupto: se conserva el valor por defecto.
      }
    }

    // 2. Si hay sesión en Supabase, intenta refrescar con la base de datos.
    final cliente = _supabase;
    final usuarioId = cliente?.auth.currentUser?.id;
    if (cliente != null && usuarioId != null) {
      try {
        final fila = await cliente
            .from('preferencias_recordatorio')
            .select('activo, hora, minuto, beneficio_explicado')
            .eq('usuario_id', usuarioId)
            .maybeSingle();

        if (fila != null) {
          preferencias = preferencias.copyWith(
            activo: fila['activo'] as bool? ?? preferencias.activo,
            hora: (fila['hora'] as num?)?.toInt() ?? preferencias.hora,
            minuto: (fila['minuto'] as num?)?.toInt() ?? preferencias.minuto,
            beneficioExplicado:
                fila['beneficio_explicado'] as bool? ??
                preferencias.beneficioExplicado,
          );
          // Actualiza la copia local con lo que vino de la nube.
          await _almacen.escribir(_clave, jsonEncode(preferencias.toJson()));
        }
      } catch (_) {
        // Sin red o error: se usa la copia local sin bloquear la app.
      }
    }

    return preferencias;
  }

  Future<void> guardar(PreferenciasRecordatorio preferencias) async {
    // 1. Guarda siempre en local primero.
    await _almacen.escribir(_clave, jsonEncode(preferencias.toJson()));

    // 2. Si hay sesión, sincroniza con Supabase mediante la RPC de RF-22.
    final cliente = _supabase;
    if (cliente?.auth.currentUser != null) {
      try {
        await cliente!.rpc(
          'guardar_preferencias_recordatorio',
          params: {
            'p_activo': preferencias.activo,
            'p_hora': preferencias.hora,
            'p_minuto': preferencias.minuto,
            'p_beneficio_explicado': preferencias.beneficioExplicado,
          },
        );
      } catch (_) {
        // Si no hay internet, queda guardado en local y la alarma funciona igual.
      }
    }
  }
}
