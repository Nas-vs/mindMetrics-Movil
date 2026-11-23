import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_datos;
import 'package:timezone/timezone.dart' as tz;

/// Lo que el recordatorio necesita del sistema de notificaciones.
///
/// Es una interfaz para poder probar [RecordatorioServicio] sin un celular.
abstract class NotificacionesServicio {
  /// Pide el permiso del sistema (Android 13+ e iOS). true = concedido.
  Future<bool> pedirPermiso();

  /// Programa una notificación en una fecha y hora local.
  Future<void> programar({
    required int id,
    required DateTime cuando,
    required String titulo,
    required String texto,
  });

  Future<void> cancelar(int id);
  Future<void> cancelarTodas();

  /// Notificación inmediata (botón "Probar notificación").
  Future<void> mostrarAhora({required String titulo, required String texto});
}

/// Implementación real con flutter_local_notifications.
class NotificacionesLocales implements NotificacionesServicio {
  NotificacionesLocales([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// RF-22 CA-4: dato que viaja en la notificación para saber a dónde ir.
  static const payloadRegistroAnimo = 'registro_animo';

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorio_diario',
      'Recordatorio diario',
      channelDescription: 'Te recuerda registrar cómo te sientes cada día.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Se llama UNA vez al abrir la app (en main.dart).
  ///
  /// [alTocar] se ejecuta cuando el usuario toca una notificación con la app
  /// abierta o en segundo plano. Devuelve true si la app se ABRIÓ desde una
  /// notificación (app cerrada), para que main.dart navegue al registro.
  Future<bool> inicializar({required VoidCallback alTocar}) async {
    await _configurarZonaHoraria();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // El permiso NO se pide al abrir la app (CA-1): se pide después del
        // primer registro, con pedirPermiso().
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (respuesta) {
        if (respuesta.payload == payloadRegistroAnimo) alTocar();
      },
    );

    final lanzamiento = await _plugin.getNotificationAppLaunchDetails();
    return (lanzamiento?.didNotificationLaunchApp ?? false) &&
        lanzamiento?.notificationResponse?.payload == payloadRegistroAnimo;
  }

  Future<void> _configurarZonaHoraria() async {
    tz_datos.initializeTimeZones();
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      // Si el sistema no responde, usamos la hora de Colombia.
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }
  }

  @override
  Future<bool> pedirPermiso() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> programar({
    required int id,
    required DateTime cuando,
    required String titulo,
    required String texto,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime(
        tz.local,
        cuando.year,
        cuando.month,
        cuando.day,
        cuando.hour,
        cuando.minute,
      ),
      notificationDetails: _detalles,
      // Inexacta: puede llegar unos minutos tarde, pero no exige el permiso
      // especial de "alarmas exactas" de Android 14.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: titulo,
      body: texto,
      payload: payloadRegistroAnimo,
    );
  }

  @override
  Future<void> cancelar(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelarTodas() => _plugin.cancelAll();

  @override
  Future<void> mostrarAhora({required String titulo, required String texto}) {
    return _plugin.show(
      id: 1,
      title: titulo,
      body: texto,
      notificationDetails: _detalles,
      payload: payloadRegistroAnimo,
    );
  }
}
