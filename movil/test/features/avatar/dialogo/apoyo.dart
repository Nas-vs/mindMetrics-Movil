import 'dart:convert';
import 'dart:io';

import 'package:app_bienestar/features/avatar/domain/dialogo/guion.dart';

/// Carga el guion real desde el asset (las pruebas corren desde `movil/`).
Guion cargarGuion() => Guion.deJson(
      jsonDecode(File('assets/guiones/encuesta_inicial_v1.json').readAsStringSync())
          as Map<String, dynamic>,
    );

/// Casos compartidos con la referencia en Python (`tool/avatar/dialogo_referencia.py`).
Map<String, dynamic> cargarCasos(String nombre) =>
    jsonDecode(File('test/features/avatar/dialogo/$nombre').readAsStringSync())
        as Map<String, dynamic>;

PreguntaGuion pregunta(Guion g, String campo) => g.preguntas.firstWhere((p) => p.campo == campo);
