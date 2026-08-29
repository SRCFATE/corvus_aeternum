import 'package:corvus_aeternum/core/router/navigation_coordinator.dart';
import 'package:corvus_aeternum/features/home/home_shell.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/providers/conspiration_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() {
  Future<GoRouter> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/atelier',
      routes: [
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (_, __, child) => HomeShell(child: child),
          routes: [
            GoRoute(
              path: '/atelier',
              builder: (_, __) => const ColoredBox(
                key: ValueKey('atelier-workspace'),
                color: Colors.black,
              ),
            ),
            GoRoute(
              path: '/discover',
              builder: (_, __) => const Center(
                key: ValueKey('discover-page'),
                child: Text('Destino descubrir'),
              ),
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
          // La topbar se tiñe con el acento de la casa activa.
          ChangeNotifierProvider(create: (_) => ConspirationProvider()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openEditor(WidgetTester tester) async {
    final workspaceContext =
        tester.element(find.byKey(const ValueKey('atelier-workspace')));
    Navigator.of(workspaceContext).push(
      MaterialPageRoute<void>(
        builder: (_) => const ColoredBox(
          key: ValueKey('open-editor'),
          color: Colors.black,
          child: Center(child: Text('Editor abierto')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('topbar closes an Atelier editor before changing category',
      (tester) async {
    final router = await pumpShell(tester);
    await openEditor(tester);

    expect(find.byKey(const ValueKey('open-editor')), findsOneWidget);
    await tester.tap(find.text('Descubrir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Deseas cambiar de página?'), findsOneWidget);
    await tester.tap(find.text('Salir y cambiar'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/discover');
    expect(find.byKey(const ValueKey('open-editor')), findsNothing);
    expect(find.byKey(const ValueKey('discover-page')), findsOneWidget);
  });

  testWidgets('topbar respects a workspace exit guard', (tester) async {
    final router = await pumpShell(tester);
    await openEditor(tester);
    final owner = Object();
    AppNavigationCoordinator.instance.registerExitGuard(owner, () async {
      return false;
    });
    addTearDown(
      () => AppNavigationCoordinator.instance.unregisterExitGuard(owner),
    );

    await tester.tap(find.text('Descubrir'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/atelier');
    expect(find.byKey(const ValueKey('open-editor')), findsOneWidget);
  });
}
