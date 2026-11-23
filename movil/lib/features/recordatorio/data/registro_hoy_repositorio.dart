import 'package:supabase_flutter/supabase_flutter.dart';

/// ¿El usuario ya registró su ánimo hoy? (RF-22 CA-3)
///
/// Consulta la tabla de RF-08 (`registros_animo`). "Hoy" es el día LOCAL
/// del celular, igual que como lo guarda RF-08.
abstract class RegistroHoyRepositorio {
  Future<bool> yaRegistroHoy();
}

class RegistroHoySupabase implements RegistroHoyRepositorio {
  RegistroHoySupabase(this._db);

  final SupabaseClient _db;

  @override
  Future<bool> yaRegistroHoy() async {
    final ahora = DateTime.now();
    final hoy = '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';
    final fila = await _db
        .from('registros_animo')
        .select('id')
        .eq('fecha', hoy)
        .maybeSingle();
    return fila != null;
  }
}
