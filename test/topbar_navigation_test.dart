import 'package:corvus_aeternum/core/router/navigation_coordinator.dart';
import 'package:corvus_aeternum/features/home/home_shell.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/providers/conspiration_provider.dart';
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
}
