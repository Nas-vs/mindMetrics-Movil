import 'package:app_bienestar/features/animo/data/registro_animo_repositorio.dart';
import 'package:app_bienestar/features/animo/domain/registro_animo.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Repositorio en memoria para probar RF-08 sin Supabase.
class RepositorioAnimoFalso implements RegistroAnimoRepositorio {
  RepositorioAnimoFalso({
    this.existente,
    this.resultado = ResultadoGuardado.sincronizado,
    this.errorServidor,
    this.alerta,
  });

  RegistroAnimo? existente;
  ResultadoGuardado resultado;
  String? errorServidor;
  AlertaBienestar? alerta;

  final guardados = <RegistroAnimo>[];
  final alertasVistas = <String>[];

  @override
  Future<List<OpcionCatalogo>> emociones() async =>
      const [OpcionCatalogo(id: 1, nombre: 'Alegría'), OpcionCatalogo(id: 2, nombre: 'Calma')];

  @override
  Future<List<OpcionCatalogo>> factores() async =>
      const [OpcionCatalogo(id: 1, nombre: 'Sueño')];

  @override
  Future<RegistroAnimo?> registroDe(String fecha) async =>
      existente?.fecha == fecha ? existente : null;

  @override
  Future<ResultadoGuardado> guardar(RegistroAnimo registro) async {
    if (errorServidor != null) throw PostgrestException(message: errorServidor!);
    guardados.add(registro);
    return resultado;
  }

  @override
  Future<void> sincronizarPendientes() async {}

  @override
  Future<AlertaBienestar?> alertaPendiente() async => alerta;

  @override
  Future<void> marcarAlertaVista(String id) async => alertasVistas.add(id);
}
