import 'package:corvus_aeternum/features/atelier/atelier_page.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/providers/conspiration_provider.dart';
import 'package:corvus_aeternum/providers/entitlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpAtelier(
    WidgetTester tester, {
    required Size size,
    AtelierInitialSection initialSection = AtelierInitialSection.home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ConspirationProvider()),
          ChangeNotifierProvider(create: (_) => AtelierProvider()),
          // La barra del taller muestra el plan activo: sin este proveedor la
          // pantalla no se puede montar.
          ChangeNotifierProvider(create: (_) => EntitlementProvider()),
        ],
        child: MaterialApp(
          home: AtelierPage(initialSection: initialSection),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Atelier renders on desktop without layout exceptions',
      (tester) async {
    await pumpAtelier(tester, size: const Size(1400, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('Atelier'), findsWidgets);
    expect(find.text('Inicia sesion para usar Atelier'), findsOneWidget);
  });

  testWidgets('Atelier renders on mobile without layout exceptions',
      (tester) async {
    await pumpAtelier(tester, size: const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Atelier'), findsWidgets);
    expect(find.text('Inicia sesion para usar Atelier'), findsOneWidget);
  });

  testWidgets('Mundiarium opens as a first-class workspace', (tester) async {
    await pumpAtelier(
      tester,
      size: const Size(1400, 900),
      initialSection: AtelierInitialSection.mundiarium,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Mundiarium'), findsOneWidget);
    expect(find.text('Universos y continuidad transmedia'), findsOneWidget);
  });

  testWidgets('Archivo opens as a first-class workspace', (tester) async {
    await pumpAtelier(
      tester,
      size: const Size(390, 844),
      initialSection: AtelierInitialSection.archive,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Archivo Aeternum'), findsOneWidget);
    expect(find.text('Ideas, referencias y memoria creativa'), findsOneWidget);
  });
}
