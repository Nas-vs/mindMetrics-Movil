import 'dart:async';

import 'package:app_bienestar/features/avatar/data/guion_repositorio.dart';
import 'package:app_bienestar/features/avatar/domain/dialogo/guion.dart';
import 'package:app_bienestar/features/avatar/domain/servicio_voz.dart';
import 'package:app_bienestar/features/avatar/presentation/consentimiento_voz.dart';
import 'package:app_bienestar/features/avatar/presentation/conversacion_pagina.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialogo/apoyo.dart';

/// Guion cargado del archivo real, sin pasar por rootBundle.
class _GuionFijo extends GuionRepositorio {
  _GuionFijo(this.guion);
  final Guion guion;

  @override
  Future<Guion> cargar([String ruta = GuionRepositorio.encuestaInicial]) async => guion;
}

/// Voz controlada por la prueba: habla al instante y escucha hasta que la
/// prueba llame a [oir].
class _VozControlada implements ServicioVoz {
  Completer<String?>? _pendiente;

  @override
  bool get admiteEscucha => true;

  @override
  Future<void> hablar(String texto) async {}

  @override
  Future<String?> escuchar() => (_pendiente = Completer<String?>()).future;

  void oir(String? texto) => _pendiente?.complete(texto);

  @override
  Future<void> detener() async {
    final p = _pendiente;
    if (p != null && !p.isCompleted) p.complete(null);
  }
}

void main() {
  final guion = cargarGuion();
  late List<Map<String, Object>> guardadas;
  ResultadoConversacion? resultado;

  setUp(() {
    guardadas = [];
    resultado = null;
  });

  /// Abre la página desde un botón para poder leer lo que devuelve al cerrarse.
  Future<void> abrir(
    WidgetTester tester, {
    required ModoConversacion? modo,
    PrepararVoz? prepararVoz,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            resultado = await Navigator.of(context).push<ResultadoConversacion>(MaterialPageRoute(
              builder: (_) => ConversacionPagina(
                repositorioGuion: _GuionFijo(guion),
                elegirModo: (_) async => modo,
                prepararVoz: prepararVoz ?? () async => (null, null),
                guardar: (fila) async => guardadas.add(fila),
              ),
            ));
          },
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pump(); // navega
    await tester.pump(const Duration(milliseconds: 400)); // transición + arranque
  }

  String subtitulo(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('subtitulo'))).data!;

  Future<void> escribir(WidgetTester tester, String texto) async {
    await tester.enterText(find.byKey(const ValueKey('entrada')), texto);
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump(const Duration(seconds: 5)); // deja terminar de "hablar"
  }

  testWidgets('escribiendo: saluda con el nombre de la mascota y avanza', (tester) async {
    await abrir(tester, modo: ModoConversacion.texto);
    await tester.pump(const Duration(seconds: 5));
    expect(subtitulo(tester), contains('Soy Nimbus'));

    await escribir(tester, 'mujer');
    expect(subtitulo(tester), contains('situación sentimental'));
  });

  testWidgets('crisis: muestra las líneas de ayuda con botón de llamar', (tester) async {
    await abrir(tester, modo: ModoConversacion.texto);
    await tester.pump(const Duration(seconds: 5));
    await escribir(tester, 'no quiero vivir');
    // La ayuda aparece al terminar de hablar; da frames para que la lista
    // baje hasta ella (debe quedar a la vista, no solo existir).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // La tarjeta queda a la vista (al menos en parte: la pantalla de prueba
    // es de 800×600 con una fuente más ancha que la del celular)...
    expect(find.byKey(const ValueKey('ayuda_crisis')), findsOneWidget);
    expect(find.textContaining('Línea 106'), findsWidgets);
    // ...y trae un botón de llamar por cada línea del guion.
    expect(find.byIcon(Icons.call, skipOffstage: false), findsNWidgets(guion.crisis.lineas.length));
  });

  testWidgets('elegir el formulario cierra la página con ese resultado', (tester) async {
    await abrir(tester, modo: ModoConversacion.formulario);
    await tester.pump(const Duration(milliseconds: 400));
    expect(resultado, ResultadoConversacion.formulario);
  });

  testWidgets('voz no disponible: avisa y sigue escribiendo', (tester) async {
    await abrir(
      tester,
      modo: ModoConversacion.voz,
      prepararVoz: () async => (null, 'Sin permiso de micrófono: seguimos escribiendo.'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sin permiso de micrófono: seguimos escribiendo.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<TextField>(find.byKey(const ValueKey('entrada'))).enabled, isTrue);
  });

  testWidgets('por voz: muestra "Te escucho" y avanza con lo que oye', (tester) async {
    final voz = _VozControlada();
    await abrir(tester, modo: ModoConversacion.voz, prepararVoz: () async => (voz, null));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('escuchando')), findsOneWidget);

    voz.oir('soy hombre');
    await tester.pump(const Duration(milliseconds: 100));
    expect(subtitulo(tester), contains('situación sentimental'));
    expect(find.byKey(const ValueKey('escuchando')), findsOneWidget);
  });

  group('dentro de la app (alSalir, apodo)', () {
    final salidas = <ResultadoConversacion>[];
    setUp(salidas.clear);

    Future<void> montar(WidgetTester tester, ModoConversacion? modo, {String? apodo}) async {
      await tester.pumpWidget(MaterialApp(
        home: ConversacionPagina(
          key: UniqueKey(), // cada montaje arranca de cero
          repositorioGuion: _GuionFijo(guion),
          elegirModo: (_) async => modo,
          prepararVoz: () async => (null, null),
          guardar: (fila) async => guardadas.add(fila),
          apodo: apodo,
          alSalir: salidas.add,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('saluda por el apodo del registro', (tester) async {
      await montar(tester, ModoConversacion.texto, apodo: 'juli_23');
      await tester.pump(const Duration(seconds: 5));
      expect(subtitulo(tester), startsWith('¡Hola, juli_23! Soy Nimbus.'));
    });

    testWidgets('no acepta (formulario o cerrar la hoja): avisa por alSalir, sin pop', (tester) async {
      await montar(tester, ModoConversacion.formulario);
      expect(salidas, [ResultadoConversacion.formulario]);
      expect(find.byType(ConversacionPagina), findsOneWidget, reason: 'no hizo pop');

      await montar(tester, null);
      expect(salidas.last, ResultadoConversacion.cancelada);
    });
  });
}
