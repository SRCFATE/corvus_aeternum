import 'dart:async';

import 'package:corvus_aeternum/features/atelier/atelier_draft_store.dart';
import 'package:corvus_aeternum/features/atelier/atelier_element_editor.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:corvus_aeternum/services/atelier_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _node = AtelierNode(
    id: 'node',
    projectId: 'project',
    profileId: 'author',
    kind: 'chapter',
    title: 'Prólogo',
    body: 'Original',
    status: 'draft',
    canonStatus: 'canon',
    visibility: 'private',
    tags: const [],
    metadata: const {},
    position: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026));

class _Service extends AtelierService {
  AtelierNode node = _node;
  int writes = 0;
  int publishing = 0;
  bool fail = false;
  Completer<void>? gate;
  bool loseFirstCreation = false;
  final createdIds = <String?>[];
  final createdBodies = <String>[];

  @override
  Future<AtelierNode> createNode(
      {String? nodeId,
      required String profileId,
      required String projectId,
      required String kind,
      required String title,
      String body = '',
      String status = 'draft',
      String canonStatus = 'canon',
      String visibility = 'private',
      List<String> tags = const [],
      Map<String, dynamic> metadata = const {},
      int position = 0}) async {
    createdIds.add(nodeId);
    createdBodies.add(body);
    if (createdIds.length == 1) {
      node = AtelierNode.fromMap({
        'id': nodeId,
        'project_id': projectId,
        'profile_id': profileId,
        'kind': kind,
        'title': title,
        'body': body,
        'status': status,
        'canon_status': canonStatus,
        'tags': tags,
        'metadata': metadata,
        'position': position
      });
      if (loseFirstCreation) throw StateError('Response lost');
    }
    return node;
  }

  @override
  Future<AtelierWorkspace> loadWorkspace(String profileId,
          {String? projectId}) async =>
      AtelierWorkspace(
          projects: const [],
          activeProject: null,
          nodes: [node],
          relations: const [],
          versions: const []);

  @override
  Future<AtelierNode> updateNode(AtelierNode next) async {
    writes++;
    await gate?.future;
    if (fail) throw StateError('offline');
    node = next;
    return next;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AtelierProvider> pumpEditor(WidgetTester tester, _Service service,
      {Size size = const Size(1440, 1000), bool fresh = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AtelierProvider(service: service);
    await provider.load('author');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
            home: AtelierElementEditor(
                profileId: 'author',
                projectId: 'project',
                initialKind: 'chapter',
                kindLabels: const {'chapter': 'Capítulo'},
                node: fresh ? null : service.node))));
    await tester.pumpAndSettle();
    return provider;
  }

  void edit(WidgetTester tester, String text) {
    final controller = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    controller.replaceText(0, controller.document.length - 1, text,
        TextSelection.collapsed(offset: text.length));
  }

  testWidgets('first save survives a lost response and keeps subsequent edits',
      (tester) async {
    final service = _Service()..loseFirstCreation = true;
    await pumpEditor(tester, service, fresh: true);
    edit(tester, 'Primera escritura');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(service.createdIds, hasLength(1));
    final store = AtelierDraftStore();
    final draft =
        (await store.pendingNew('author', 'project', 'chapter')).single.draft;
    expect(draft['creation_id'], service.createdIds.single);
    expect(draft['creation_snapshot'], isNotNull);
    edit(tester, 'Segunda escritura mientras no había respuesta');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(service.createdIds, hasLength(2));
    expect(service.createdIds.toSet(), hasLength(1));
    expect(service.createdBodies.toSet(), hasLength(1));
    expect(service.node.body, contains('Segunda escritura'));
    expect(service.writes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('starting another new draft preserves earlier unsynced work',
      (tester) async {
    final first = _Service()..loseFirstCreation = true;
    await pumpEditor(tester, first, fresh: true);
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == 'Título del capítulo'),
        'Primer borrador');
    edit(tester, 'Texto que debe conservarse');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    final second = _Service()..loseFirstCreation = true;
    await pumpEditor(tester, second, fresh: true);
    expect(find.text('Borradores pendientes'), findsOneWidget);
    expect(find.text('Primer borrador'), findsOneWidget);
    await tester.tap(find.text('Empezar otro elemento'));
    await tester.pumpAndSettle();
    edit(tester, 'Un segundo documento');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final pending =
        await AtelierDraftStore().pendingNew('author', 'project', 'chapter');
    expect(pending, hasLength(2));
    expect(
        pending.map((p) => p.draft['body']),
        containsAll([
          contains('Texto que debe conservarse'),
          contains('Un segundo documento')
        ]));
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpEditor(tester, first, fresh: true);
    await tester.tap(find.text('Primer borrador'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    expect(controller.document.toPlainText(),
        contains('Texto que debe conservarse'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('draft keys isolate accounts and queued writes preserve newest revision',
      () async {
    final store = AtelierDraftStore();
    final key = store.key('author', 'project', 'node');
    expect(key, isNot(store.key('other', 'project', 'node')));
    await Future.wait([
      store.write(key, {'body': 'uno'}),
      store.write(key, {'body': 'dos'})
    ]);
    expect((await store.read(key))!['body'], 'dos');
    await store.remove(key);
    expect(await store.read(key), isNull);
  });

  testWidgets('search navigation and focus preserve document and selection',
      (tester) async {
    final service = _Service()
      ..node = _node.copyWith(body: 'Eco primero.\n\nEco segundo.');
    await pumpEditor(tester, service);
    final controller = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    controller.updateSelection(
        const TextSelection.collapsed(offset: 4), quill.ChangeSource.local);
    final before = controller.document.toDelta().toJson();
    final selection = controller.selection;
    await tester.tap(find.text('Índice y búsqueda'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Buscar en el capítulo'), 'Eco');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Coincidencia siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('2 de 2: Eco'), findsOneWidget);
    expect(controller.document.toDelta().toJson(), before);
    expect(controller.selection, selection);
    await tester.tap(find.byTooltip('Cerrar búsqueda'));
    await tester.tap(find.byTooltip('Modo concentración'));
    await tester.pumpAndSettle();
    expect(controller.document.toDelta().toJson(), before);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Índice y búsqueda'), findsOneWidget);
    expect(service.writes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pinned inspector preserves editing and remembers its state',
      (tester) async {
    final service = _Service();
    await pumpEditor(tester, service);
    await tester.tap(find.text('Dossier').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fijar panel'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Desfijar panel'), findsOneWidget);
    edit(tester, 'Texto con el panel abierto');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(service.node.body, contains('Texto con el panel abierto'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('atelier.panelPinned.author'), isTrue);
    expect(preferences.getBool('atelier.panelOpen.author'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Desfijar panel'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('autosave preserves edits made during a pending request',
      (tester) async {
    final service = _Service()..gate = Completer<void>();
    await pumpEditor(tester, service);
    edit(tester, 'Primera revisión');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(service.writes, 1);
    edit(tester, 'Segunda revisión');
    await tester.pump(const Duration(seconds: 3));
    expect(service.writes, 1);
    service.gate!.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(service.node.body, contains('Segunda revisión'));
    expect(service.writes, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline changes survive reopening and can be recovered',
      (tester) async {
    final service = _Service()..fail = true;
    await pumpEditor(tester, service);
    edit(tester, 'Mi texto protegido');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error de sincronización'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpEditor(tester, service);
    expect(find.text('Recuperar borrador'), findsOneWidget);
    await tester.tap(find.text('Recuperar cambios'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    expect(controller.document.toPlainText(), contains('Mi texto protegido'));
    expect(service.node.body, 'Original');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('small mobile editor keeps toolbar and panels usable',
      (tester) async {
    await pumpEditor(tester, _Service(), size: const Size(320, 740));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Dossier'));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar panel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  test('trash preserves content and can restore the original id', () async {
    final service = _Service();
    final provider = AtelierProvider(service: service);
    await provider.load('author');
    await provider.deleteNode('author', _node);
    expect(provider.nodes, isEmpty);
    expect(provider.trashedNodes.single.body, 'Original');
    await provider.restoreNode(provider.trashedNodes.single);
    expect(provider.nodes.single.id, 'node');
    expect(provider.trashedNodes, isEmpty);
  });
}
