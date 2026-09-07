import 'package:corvus_aeternum/core/router/navigation_coordinator.dart';
import 'package:corvus_aeternum/features/home/home_shell.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/providers/conspiration_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// La topbar es el mapa mental de Corvus: seis destinos principales más
/// "Más". Estas pruebas fijan esa estructura para que no vuelva a crecer sin
/// una decisión explícita.
void main() {
  Future<GoRouter> pumpShell(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const paths = [
      '/feed', '/discover', '/collections', '/profile', '/auctions',
      '/artists', '/atelier', '/mundiarium', '/archive', '/certificates',
      '/insights', '/planner', '/arena', '/glossary', '/conspiracies',
      '/forums',
    ];

    final router = GoRouter(
      initialLocation: '/discover',
      routes: [
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (_, __, child) => HomeShell(child: child),
          routes: [
            for (final p in paths)
              GoRoute(
                path: p,
                builder: (_, __) => Center(key: ValueKey('page$p'), child: Text(p)),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ConspirationProvider()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('escritorio muestra los seis destinos principales más "Más"',
      (tester) async {
    await pumpShell(tester);

    for (final label in [
      'Descubrir', 'Explorar', 'Atelier', 'Ranking', 'Colecciones', 'Subastas',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'falta $label en la barra');
    }
    expect(find.text('Más'), findsOneWidget);
  });

  testWidgets('Arena y Foros salieron de la barra principal', (tester) async {
    await pumpShell(tester);

    expect(find.text('Arena'), findsNothing);
    expect(find.text('Foros'), findsNothing);
    // "Artistas" se renombró: Corvus no es solo literario.
    expect(find.text('Artistas'), findsNothing);
  });

  testWidgets('el menú "Más" agrupa comunidad, trayectoria y archivo',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    // Encabezados de grupo
    expect(find.text('COMUNIDAD'), findsOneWidget);
    expect(find.text('TRAYECTORIA'), findsOneWidget);
    expect(find.text('ARCHIVO Y ORGANIZACIÓN'), findsOneWidget);

    // Los destinos que bajaron de la barra viven aquí
    expect(find.text('Arena Corvus'), findsOneWidget);
    expect(find.text('Foros de autores'), findsOneWidget);
    expect(find.text('Libro de las Conspiraciones'), findsOneWidget);
    expect(find.text('Glosario'), findsOneWidget);

    // En escritorio ancho el panel despliega las tres columnas de verdad.
    final tileRow = find
        .ancestor(of: find.text('Arena Corvus'), matching: find.byType(Row))
        .first;
    expect(tester.getSize(tileRow).width, greaterThan(180),
        reason: 'las columnas del panel se colapsaron');
  });

  testWidgets('resaltar un destino con el cursor no desborda su fila',
      (tester) async {
    // El desborde real aparecía solo al resaltar: la flecha de la derecha
    // añade ancho a una fila ya ajustada.
    await pumpShell(tester, size: const Size(1024, 768));

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    for (final label in ['Arena Corvus', 'Certificados', 'Glosario']) {
      await gesture.moveTo(tester.getCenter(find.text(label)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'desbordó al resaltar "$label"');
    }
  });

  testWidgets('el menú "Más" no desborda en una ventana de escritorio estrecha',
      (tester) async {
    // El panel vive dentro de un BackdropFilter, que no reporta ancho
    // intrínseco: si el ancho no se fija por fuera, el menú se colapsa y las
    // filas de cada destino desbordan.
    await pumpShell(tester, size: const Size(900, 700));

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Arena Corvus'), findsOneWidget);

    // No basta con que el texto exista: si el panel se colapsa, el destino
    // queda ilegible y la fila desborda en cuanto el cursor lo resalta.
    final tileRow = find
        .ancestor(of: find.text('Arena Corvus'), matching: find.byType(Row))
        .first;
    expect(tester.getSize(tileRow).width, greaterThan(160),
        reason: 'el panel del menú se colapsó');
  });

  testWidgets('elegir un destino del menú navega hasta él', (tester) async {
    final router = await pumpShell(tester);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arena Corvus'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/arena');
  });

  testWidgets('la barra móvil conserva la misma jerarquía', (tester) async {
    await pumpShell(tester, size: const Size(420, 900));

    for (final label in [
      'Descubrir', 'Explorar', 'Atelier', 'Ranking', 'Colecciones',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'falta $label en móvil');
    }
  });

  // ── Navegación táctil ──────────────────────────────────────────────────
  // Los destinos estaban arriba, en dos filas, donde el pulgar no llega sin
  // recolocar la mano. Bajaron. Estas pruebas fijan que sigan abajo.

  testWidgets('en móvil los destinos viven en la mitad inferior',
      (tester) async {
    await pumpShell(tester, size: const Size(420, 900));

    // El criterio no es "existe", es "se alcanza": por debajo de la mitad de
    // una pantalla de 900 px.
    for (final label in ['Descubrir', 'Atelier', 'Colecciones']) {
      final centro = tester.getCenter(find.text(label).last);
      expect(centro.dy, greaterThan(450),
          reason: '$label quedó fuera del alcance del pulgar');
    }
  });

  testWidgets('el cajón móvil ofrece los destinos secundarios',
      (tester) async {
    final router = await pumpShell(tester, size: const Size(420, 900));

    // Antes de abrirlo, lo secundario no está en pantalla.
    expect(find.text('Arena Corvus'), findsNothing);

    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();

    expect(find.text('Arena Corvus'), findsOneWidget);
    expect(find.text('Foros de autores'), findsOneWidget);
    // Subastas no cabe entre los cinco de la barra inferior, así que el cajón
    // es su única puerta en táctil: si desaparece de aquí, desaparece.
    expect(find.text('Subastas'), findsWidgets);

    // El último grupo queda por debajo del pliegue y la lista lo construye al
    // llegar: hay que desplazarse hasta él, y llegar es justo lo que se
    // comprueba.
    await tester.scrollUntilVisible(
      find.text('Glosario'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Glosario'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Arena Corvus'),
      -200,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(find.text('Arena Corvus'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/arena');
    // Y el cajón se cierra solo: quedarse abierto sobre el destino recién
    // elegido obligaría a un gesto de más.
    expect(find.text('Foros de autores'), findsNothing);
  });

  testWidgets('escritorio no duplica la navegación en un cajón',
      (tester) async {
    await pumpShell(tester);

    expect(find.byTooltip('Menú'), findsNothing);
    expect(find.byType(Drawer), findsNothing);
  });
}
