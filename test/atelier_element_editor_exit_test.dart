import 'package:corvus_aeternum/features/atelier/atelier_element_editor.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final node = AtelierNode(
    id: 'node-1',
    projectId: 'project-1',
    profileId: 'profile-1',
    kind: 'chapter',
    title: 'Prologo',
    body: 'Texto guardado',
    status: 'active',
    canonStatus: 'canon',
    visibility: 'private',
    tags: const [],
    metadata: const {},
    position: 0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AtelierProvider(),
        child: MaterialApp(
          home: AtelierElementEditor(
            profileId: 'profile-1',
            projectId: 'project-1',
            initialKind: 'chapter',
            kindLabels: const {'chapter': 'Capitulo'},
            node: node,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('back arrow confirms exit even when the editor is clean',
      (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Deseas salir del editor?'), findsOneWidget);
    expect(find.text('Seguir editando'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);
  });

  testWidgets('back arrow warns explicitly about unsaved changes',
      (tester) async {
    await pumpEditor(tester);
    final bodyField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.expands,
    );

    await tester.enterText(bodyField, 'Texto modificado sin guardar');
    await tester.pump();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Deseas salir sin guardar?'), findsOneWidget);
    expect(find.text('Descartar cambios'), findsOneWidget);
    expect(find.text('Guardar y salir'), findsOneWidget);
    expect(find.text('Seguir editando'), findsOneWidget);
  });
}
