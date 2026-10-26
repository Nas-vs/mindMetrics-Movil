// "Cerrar sesión" en el menú lateral.
// Se corre con:   flutter test test/features/auth/sesion/

import 'package:app_bienestar/features/auth/sesion/data/sesion_repositorio.dart';
import 'package:app_bienestar/features/onboarding/core/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SesionFalsa implements SesionRepositorio {
  int cierres = 0;

  @override
  Future<void> cerrarSesion() async => cierres++;
}

Future<SesionFalsa> montarMenu(WidgetTester tester) async {
  final sesion = SesionFalsa();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sesionRepositorioProvider.overrideWithValue(sesion)],
      child: const MaterialApp(
        home: Scaffold(drawer: AppDrawer(), body: SizedBox()),
      ),
    ),
  );
  tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  await tester.pumpAndSettle();
  return sesion;
}

void main() {
  testWidgets('pide confirmación y cierra la sesión', (tester) async {
    final sesion = await montarMenu(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    // El botón del diálogo (el último "Cerrar sesión" en pantalla).
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();
    expect(sesion.cierres, 1);
  });

  testWidgets('"Cancelar" no cierra la sesión', (tester) async {
    final sesion = await montarMenu(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(sesion.cierres, 0);
  });
}
