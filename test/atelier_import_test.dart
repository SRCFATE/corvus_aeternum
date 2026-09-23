import 'dart:convert';
import 'package:corvus_aeternum/features/atelier/atelier_project_import.dart';
import 'package:corvus_aeternum/features/atelier/atelier_import_dialog.dart';
import 'package:corvus_aeternum/features/atelier/atelier_publication_review.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> exportFixture() => {
      'project': {
        'id': '00000000-0000-4000-8000-000000000001',
        'title': 'La biblioteca'
      },
      'nodes': [
        {
          'id': '00000000-0000-4000-8000-000000000002',
          'title': 'Primero',
          'body': 'Texto',
          'kind': 'chapter'
        }
      ],
      'relations': <dynamic>[],
      'versions': <dynamic>[],
    };

void main() {
  test('validates export and keeps one request identity per preview', () {
    final project = AtelierProjectImport.parse(jsonEncode(exportFixture()));
    expect(project.title, 'La biblioteca');
    expect(project.nodeCount, 1);
    expect(project.requestId, matches(RegExp(r'^[a-f0-9-]{36}$')));
    expect(AtelierProjectImport.parse(jsonEncode(exportFixture())).requestId,
        isNot(project.requestId));
    for (final source in [
      '{',
      '{}',
      '[]',
      jsonEncode({...exportFixture(), 'nodes': 'wrong'})
    ]) {
      expect(() => AtelierProjectImport.parse(source), throwsFormatException);
    }
    final duplicated = exportFixture();
    (duplicated['nodes'] as List).add((duplicated['nodes'] as List).first);
    expect(() => AtelierProjectImport.parse(jsonEncode(duplicated)),
        throwsFormatException);
    final broken = exportFixture();
    broken['relations'] = [
      {'source_node_id': 'missing', 'target_node_id': 'missing'}
    ];
    expect(() => AtelierProjectImport.parse(jsonEncode(broken)),
        throwsFormatException);
  });

  testWidgets('mobile import preview retries without changing request identity',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = AtelierProjectImport.parse(jsonEncode(exportFixture()));
    final attempts = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AtelierImportDialog(
                            project: project,
                            onImport: () async {
                              attempts.add(project.requestId);
                              if (attempts.length == 1) {
                                throw StateError('lost response');
                              }
                            })),
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('La biblioteca'), findsOneWidget);
    await tester.tap(find.text('Restaurar como copia privada'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(attempts, [project.requestId, project.requestId]);
    expect(find.text('Recuperar proyecto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('large revision warning ignores typos in long paragraphs', () {
    final before = List.filled(100, 'La luna ilumina el archivo.').join(' ');
    AtelierNode node(String text) => AtelierNode.fromMap({
          'id': 'chapter',
          'project_id': 'project',
          'profile_id': 'owner',
          'title': 'Capítulo',
          'body': text,
          'kind': 'chapter',
          'status': 'done'
        });
    List<PublicationIssue> review(String body) =>
        reviewAtelierPublication([node(body)],
            previousBodies: {'chapter': before});
    expect(
        review(before.replaceFirst('luna', 'Luna'))
            .where((i) => i.message.contains('extensa')),
        isEmpty);
    expect(
        review(List.filled(100, 'Otra historia empieza lejos.').join(' '))
            .where((i) => i.message.contains('extensa')),
        hasLength(1));
  });

  test('version identifies author from the authorized profile join', () {
    final version = AtelierVersion.fromMap({
      'id': 'v',
      'project_id': 'p',
      'profile_id': 'u',
      'profiles': {'display_name': 'Ana'}
    });
    expect(version.authorName, 'Ana');
    expect(version.toExportMap()['author_name'], 'Ana');
  });
}
