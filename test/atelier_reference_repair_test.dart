import 'package:corvus_aeternum/features/atelier/atelier_reference_repair.dart';
import 'package:corvus_aeternum/features/atelier/atelier_reference_repair_sheet.dart';
import 'package:corvus_aeternum/features/atelier/atelier_element_editor.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:corvus_aeternum/services/atelier_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

AtelierNode node(String id, String title,
        {String kind = 'character',
        String body = '',
        Map<String, dynamic> metadata = const {}}) =>
    AtelierNode.fromMap({
      'id': id,
      'title': title,
      'project_id': 'p',
      'profile_id': 'u',
      'kind': kind,
      'body': body,
      'metadata': metadata
    });

class MemoryReferences extends AtelierService {
  List<AtelierNode> nodes;
  MemoryReferences(this.nodes);
  @override
  Future<AtelierWorkspace> loadWorkspace(String profileId,
          {String? projectId}) async =>
      AtelierWorkspace(
          projects: [],
          activeProject: null,
          nodes: nodes,
          relations: [],
          versions: []);
  @override
  Future<AtelierNode> updateNode(AtelierNode value) async {
    nodes = nodes.map((n) => n.id == value.id ? value : n).toList();
    return value;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'explicit references support aliases and preserve custom labels and code',
      () {
    final target = node('ana', 'Ana nueva', metadata: {
      'alias': 'La viajera',
      'aliases': ['Ana']
    });
    final delta = <Map<String, dynamic>>[
      {'insert': 'Ana casual. [[Ana]] y [[La viajera|Ella]]. '},
      {
        'insert': '[[Ana]]',
        'attributes': {'code': true}
      },
      {'insert': '\n[[Ana]]'},
      {
        'insert': '\n',
        'attributes': {'code-block': true}
      },
      {
        'insert': 'Ana',
        'attributes': {'link': 'corvus-node:ana'}
      },
      {'insert': ' y '},
      {
        'insert': 'La protagonista',
        'attributes': {'link': 'corvus-node:ana'}
      },
      {'insert': '\n'},
    ];
    final repairs = atelierReferenceRepairs(delta, [target]);
    expect(repairs, hasLength(3));
    expect(repairs[0].source, '[[Ana]]');
    expect(repairs[0].replacement(target), 'Ana nueva');
    expect(repairs[1].replacement(target), 'Ella');
    expect(repairs[2].renamed, isTrue);
    expect(
        atelierReferenceRepairs([
          {'insert': '[[Ana]]'}
        ], [
          target,
          node('other', 'Ana')
        ]).single.candidates,
        hasLength(2));
  });
  test('renaming a world node retains its stable id and old name as alias',
      () async {
    final original = node('ana', 'Ana');
    final service = MemoryReferences([original]);
    final provider = AtelierProvider(service: service);
    await provider.load('u');
    await provider.updateNode(original.copyWith(title: 'Elena'));
    expect(provider.worldNodes.single.id, 'ana');
    expect(atelierNameMatches(provider.worldNodes.single, 'Ana'), isTrue);
    provider.dispose();
  });
  testWidgets('ambiguous references require a choice on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repairs = atelierReferenceRepairs([
      {'insert': '[[Ana]]'}
    ], [
      node('a', 'Ana', body: 'La viajera'),
      node('b', 'Ana', body: 'La guardiana')
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AtelierReferenceRepairSheet(repairs: repairs))));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana — La guardiana').last);
    await tester.pumpAndSettle();
    expect(find.text('Aplicar 1 cambio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('editor converts selected wikilinks and keeps them after saving',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chapter =
        node('chapter', 'Prólogo', kind: 'chapter', body: 'Hola [[Ana]].');
    final service = MemoryReferences([chapter, node('ana', 'Ana')]);
    final provider = AtelierProvider(service: service);
    await provider.load('u');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
            home: AtelierElementEditor(
                profileId: 'u',
                projectId: 'p',
                initialKind: 'chapter',
                kindLabels: const {'chapter': 'Capítulo'},
                node: chapter))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar referencias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar 1 cambio'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    expect(controller.document.toPlainText(), 'Hola Ana.\n');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(service.nodes.first.body, contains('[Ana](corvus-node:ana)'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}
