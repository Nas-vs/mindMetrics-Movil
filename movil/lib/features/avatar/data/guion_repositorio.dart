import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/dialogo/guion.dart';

/// Carga guiones desde los assets (`assets/guiones/`).
class GuionRepositorio {
  const GuionRepositorio({this._bundle});

  static const encuestaInicial = 'assets/guiones/encuesta_inicial_v1.json';

  final AssetBundle? _bundle;

  Future<Guion> cargar([String ruta = encuestaInicial]) async {
    final texto = await (_bundle ?? rootBundle).loadString(ruta);
    return Guion.deJson(jsonDecode(texto) as Map<String, dynamic>);
  }
}
