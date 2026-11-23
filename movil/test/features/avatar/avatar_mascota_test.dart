import 'package:app_bienestar/features/avatar/domain/estado_avatar.dart';
import 'package:app_bienestar/features/avatar/domain/personaje_avatar.dart';
import 'package:app_bienestar/features/avatar/presentation/avatar_controlador.dart';
import 'package:app_bienestar/features/avatar/presentation/avatar_mascota.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _opacidad(WidgetTester tester, String capa) =>
    tester.widget<Opacity>(find.byKey(ValueKey('capa_$capa'))).opacity;

Future<AvatarControlador> _montar(
  WidgetTester tester, {
  PersonajeAvatar personaje = PersonajesAvatar.nimbus,
}) async {
  final c = AvatarControlador();
  addTearDown(c.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Center(child: AvatarMascota(personaje: personaje, controlador: c)),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  return c;
}

void main() {
  for (final p in PersonajesAvatar.todos) {
    testWidgets('${p.id}: en reposo muestra ojos abiertos y sonrisa',
        (tester) async {
      await _montar(tester, personaje: p);
      expect(_opacidad(tester, 'ojos_abiertos'), 1);
      expect(_opacidad(tester, 'boca_sonrisa'), 1);
      expect(_opacidad(tester, 'boca_media'), 0);
      expect(_opacidad(tester, 'extra_pensando'), 0);
    });
  }

  testWidgets('pensar muestra burbujas y ojos hacia arriba', (tester) async {
    final c = await _montar(tester);
    c.pensar();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_opacidad(tester, 'ojos_pensando'), 1);
    expect(_opacidad(tester, 'extra_pensando'), greaterThan(0));
  });

  testWidgets('escuchar muestra el anillo', (tester) async {
    final c = await _montar(tester);
    expect(find.byKey(const ValueKey('avatar_anillo')), findsNothing);
    c.escuchar();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const ValueKey('avatar_anillo')), findsOneWidget);
  });

  testWidgets('hablar con nivel externo abre la boca', (tester) async {
    final c = await _montar(tester);
    c.hablar(emocion: EmocionAvatar.neutral);
    c.actualizarNivelVoz(0.9);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_opacidad(tester, 'boca_abierta'), 1);
    expect(_opacidad(tester, 'boca_sonrisa'), 0);
  });

  testWidgets('hablar sin nivel externo mueve la boca sola', (tester) async {
    final c = await _montar(tester);
    c.hablar();
    final vistas = <String>{};
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final b in ['cerrada', 'pequena', 'media', 'abierta', 'o']) {
        if (_opacidad(tester, 'boca_$b') == 1) vistas.add(b);
      }
    }
    expect(vistas.length, greaterThanOrEqualTo(3));
  });

  testWidgets('solo una boca y unos ojos visibles a la vez', (tester) async {
    final c = await _montar(tester);
    c.hablar();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      final visibles = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((o) {
            final k = o.key;
            if (k is! ValueKey<String>) return false;
            final v = k.value;
            return (v.startsWith('capa_boca_') || v.startsWith('capa_ojos_')) &&
                o.opacity > 0;
          })
          .length;
      expect(visibles, 2);
    }
  });

  testWidgets('expone su estado a lectores de pantalla', (tester) async {
    final c = await _montar(tester);
    c.escuchar();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.bySemanticsLabel('Nimbus, escuchando'), findsOneWidget);
  });
}
