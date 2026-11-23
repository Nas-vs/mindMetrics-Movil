import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/planta.dart';

/// Repositorio para la persistencia y lógica del Jardín Emocional (RF-16).
class JardinRepositorio {
  JardinRepositorio([this._cliente]);

  final SupabaseClient? _cliente;
  static const _clavePlanta = 'jardin_planta_activa';
  static const _claveGotasExtras = 'jardin_gotas_acumuladas';

  /// Catálogo clínico de frases amables al tocar la planta (CA-6).
  static const List<String> mensajesDeAnimo = [
    'Cuidarte cada día es tu mayor fortaleza.',
    'Paso a paso, como crecen las flores.',
    'Hoy es un buen día para ser amable contigo mismo.',
    'Incluso los días nublados ayudan a crecer.',
    'Tu bienestar florece a tu propio ritmo.',
    'Gracias por dedicarte este momento hoy.',
    'Tus emociones tienen un lugar seguro aquí.',
    'La constancia riega la calma interior.',
  ];

  /// CA-1: Lee la planta guardada en el dispositivo (o null si es la primera vez).
  Future<Planta?> obtenerPlanta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_clavePlanta);
      if (jsonStr == null) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Planta.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// CA-1 y CA-3: Guarda o actualiza la planta en almacenamiento local.
  Future<void> guardarPlanta(Planta planta) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(planta.toMap());
      await prefs.setString(_clavePlanta, jsonStr);
    } catch (_) {}
  }

  /// CA-2: Calcula cuántas gotas de agua tiene disponibles el usuario.
  /// Cada registro de ánimo otorga 1 gota.
  Future<int> obtenerGotasDisponibles(int totalRiegosRealizados) async {
    int diasRegistrados = 0;
    final cliente = _cliente;
    final usuario = cliente?.auth.currentUser;

    if (cliente != null && usuario != null) {
      try {
        final respuesta = await cliente
            .from('registros_animo')
            .select('fecha')
            .eq('usuario_id', usuario.id);
        diasRegistrados = (respuesta as List).length;
      } catch (_) {}
    }

    // Regla amable: 1 gota de bienvenida + días registrados - riegos hechos
    final gotasTotales = max(1, diasRegistrados + 1);
    final disponibles = gotasTotales - totalRiegosRealizados;
    return max(0, disponibles);
  }

  /// CA-5: Calcula los días de racha del usuario y las decoraciones desbloqueadas.
  Future<int> obtenerDiasRacha() async {
    final cliente = _cliente;
    final usuario = cliente?.auth.currentUser;
    if (cliente == null || usuario == null)
      return 7; // Racha de demostración si no hay red

    try {
      final respuesta = await cliente
          .from('registros_animo')
          .select('fecha')
          .eq('usuario_id', usuario.id)
          .order('fecha', ascending: false)
          .limit(30);

      final lista = respuesta as List;
      return lista.isNotEmpty ? lista.length : 1;
    } catch (_) {
      return 1;
    }
  }

  /// CA-4: Revisa si el usuario pasó más de un día sin ingresar ("Tu jardín te estaba esperando").
  bool estabaAusente(Planta? planta) {
    if (planta == null) return false;
    final horasSinEntrar = DateTime.now()
        .difference(planta.ultimoAcceso)
        .inHours;
    return horasSinEntrar >= 24;
  }

  /// CA-6: Elige un mensaje de ánimo aleatorio del catálogo.
  String obtenerMensajeAleatorio() {
    final random = Random();
    return mensajesDeAnimo[random.nextInt(mensajesDeAnimo.length)];
  }
}
