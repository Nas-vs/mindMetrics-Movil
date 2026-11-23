import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mensajes_recordatorio.dart';
import '../domain/planificador_recordatorio.dart';
import '../domain/preferencias_recordatorio.dart';
import 'almacen_clave_valor.dart';
import 'notificaciones_servicio.dart';
import 'preferencias_recordatorio_repositorio.dart';
import 'registro_hoy_repositorio.dart';

/// Toda la lógica de RF-22 en un solo lugar.
///
/// Quién lo usa:
/// - main.dart: [reprogramar] al abrir la app y [cancelarTodo] al cerrar sesión.
/// - RF-08 (Julián): [despuesDeRegistrarAnimo] al guardar el ánimo del día.
/// - La pantalla de configuración: [activar], [desactivar], [cambiarHora].
class RecordatorioServicio {
  RecordatorioServicio({
    required this.notificaciones,
    required this.preferencias,
    required this.registroHoy,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  /// Construcción para la app real.
  factory RecordatorioServicio.real({NotificacionesServicio? notificaciones}) {
    return RecordatorioServicio(
      notificaciones: notificaciones ?? NotificacionesLocales(),
      preferencias: PreferenciasRecordatorioRepositorio(AlmacenSeguro()),
      registroHoy: RegistroHoySupabase(Supabase.instance.client),
    );
  }

  final NotificacionesServicio notificaciones;
  final PreferenciasRecordatorioRepositorio preferencias;
  final RegistroHoyRepositorio registroHoy;
  final DateTime Function() _reloj;

  Future<PreferenciasRecordatorio> leerPreferencias() => preferencias.leer();

  /// Borra lo programado y vuelve a programar los próximos días.
  /// Es seguro llamarlo cuantas veces se quiera.
  Future<void> reprogramar() async {
    final prefs = await preferencias.leer();
    await notificaciones.cancelarTodas();
    if (!prefs.activo) return;

    final hoy = PlanificadorRecordatorio.idParaFecha(_reloj());
    var yaRegistro = prefs.ultimoDiaRegistrado == hoy;
    if (!yaRegistro) {
      try {
        yaRegistro = await registroHoy.yaRegistroHoy();
      } catch (_) {
        // Sin conexión: mejor recordar de más que de menos.
      }
    }

    final fechas = PlanificadorRecordatorio.proximasFechas(
      ahora: _reloj(),
      hora: prefs.hora,
      minuto: prefs.minuto,
      registroHoy: yaRegistro,
    );
    for (final fecha in fechas) {
      await notificaciones.programar(
        id: PlanificadorRecordatorio.idParaFecha(fecha),
        cuando: fecha,
        titulo: MensajesRecordatorio.titulo,
        texto: MensajesRecordatorio.paraFecha(fecha),
      );
    }
  }

  /// RF-08 debe llamar esto DESPUÉS de guardar el ánimo del día.
  ///
  /// - CA-3: cancela la notificación de hoy.
  /// - CA-1: la primera vez, explica el beneficio ([preguntarAlUsuario]
  ///   muestra la explicación y devuelve true si acepta) y luego pide el
  ///   permiso del sistema.
  ///
  /// Devuelve true si el recordatorio quedó activo.
  Future<bool> despuesDeRegistrarAnimo({
    required Future<bool> Function() preguntarAlUsuario,
  }) async {
    final hoy = PlanificadorRecordatorio.idParaFecha(_reloj());
    await notificaciones.cancelar(hoy);

    var prefs = (await preferencias.leer()).copyWith(ultimoDiaRegistrado: hoy);
    await preferencias.guardar(prefs);
    if (prefs.beneficioExplicado) return prefs.activo;

    final acepta = await preguntarAlUsuario();
    prefs = prefs.copyWith(beneficioExplicado: true);
    await preferencias.guardar(prefs);
    if (!acepta) return false;

    return activar();
  }

  /// Pide el permiso y, si lo da, activa y programa. true = quedó activo.
  Future<bool> activar() async {
    final permiso = await notificaciones.pedirPermiso();
    final prefs = await preferencias.leer();
    await preferencias.guardar(prefs.copyWith(activo: permiso));
    await reprogramar();
    return permiso;
  }

  Future<void> desactivar() async {
    final prefs = await preferencias.leer();
    await preferencias.guardar(prefs.copyWith(activo: false));
    await notificaciones.cancelarTodas();
  }

  Future<void> cambiarHora(int hora, int minuto) async {
    final prefs = await preferencias.leer();
    await preferencias.guardar(prefs.copyWith(hora: hora, minuto: minuto));
    await reprogramar();
  }

  /// Al cerrar sesión no se le recuerda nada a nadie.
  Future<void> cancelarTodo() => notificaciones.cancelarTodas();

  Future<void> probarAhora() => notificaciones.mostrarAhora(
        titulo: MensajesRecordatorio.titulo,
        texto: MensajesRecordatorio.paraFecha(_reloj()),
      );
}

/// main.dart lo sobrescribe con la instancia ya inicializada.
final recordatorioServicioProvider = Provider<RecordatorioServicio>(
  (ref) => RecordatorioServicio.real(),
);
