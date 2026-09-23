import 'package:corvus_aeternum/core/router/navigation_coordinator.dart';
import 'package:corvus_aeternum/shared/widgets/corvus_breadcrumbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('breadcrumbs respect unsaved editor guard and support keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final owner = Object();
    var allow = false;
    String? destination;
    AppNavigationCoordinator.instance
        .registerExitGuard(owner, () async => allow);
    addTearDown(
        () => AppNavigationCoordinator.instance.unregisterExitGuard(owner));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: CorvusBreadcrumbs(items: const [
                  CorvusCrumb('Espacios de trabajo', '/workspaces'),
                  CorvusCrumb('El estudio de los cuervos'),
                ], onNavigate: (value) async => destination = value)))));
    await tester.tap(find.text('Espacios de trabajo'));
    await tester.pump();
    expect(destination, isNull);
    allow = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(destination, '/workspaces');
    expect(tester.takeException(), isNull);
  });
}
