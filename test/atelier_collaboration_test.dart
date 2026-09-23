import 'dart:async';

import 'package:corvus_aeternum/features/atelier/atelier_comments_sheet.dart';
import 'package:corvus_aeternum/features/atelier/atelier_text_diff.dart';
import 'package:corvus_aeternum/models/atelier_comment.dart';
import 'package:corvus_aeternum/services/atelier_comment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Comments extends AtelierCommentService {
  final changes = StreamController<void>.broadcast();
  int loads = 0;
  @override
  Stream<void> watchChanges({String? projectId}) => changes.stream;
  List<String> access = ['comment.create', 'comment.resolve', 'project.write'];
  int resolved = 0;
  bool failResolve = false;
  @override
  Future<List<String>> capabilities(String projectId) async => access;
  @override
  Future<List<AtelierComment>> load(String projectId, String nodeId) async {
    loads++;
    return [
      AtelierComment(
          id: 'suggestion',
          author: 'Editora',
          body: 'Una alternativa',
          kind: 'suggestion',
          status: resolved == 0 ? 'open' : 'resolved',
          anchor: {
            ...const AtelierTextAnchor(start: 3, quote: 'cuervo').toMap(),
            'replacement': 'ave'
          },
          createdAt: DateTime(2026))
    ];
  }

  @override
  Future<void> resolve(
      String projectId, AtelierComment comment, String profileId,
      {String resolution = 'resolved'}) async {
    if (failResolve) throw StateError('offline');
    resolved++;
  }
}

void main() {
  test(
      'editorial differences preserve both versions and bound large comparisons',
      () {
    for (final pair in [
      ('A\nB\nC', 'A\nNuevo\nC'),
      ('', 'Texto'),
      ('Texto', ''),
      (
        List.generate(500, (i) => 'Antiguo $i').join('\n'),
        List.generate(500, (i) => 'Nuevo $i').join('\n')
      )
    ]) {
      final diff = compareEditorialText(pair.$1, pair.$2);
      expect(
          diff
              .where((line) => line.change != EditorialChange.added)
              .map((line) => line.text)
              .join('\n'),
          pair.$1);
      expect(
          diff
              .where((line) => line.change != EditorialChange.removed)
              .map((line) => line.text)
              .join('\n'),
          pair.$2);
    }
  });
  Future<void> open(WidgetTester tester, _Comments service,
      {String text = 'El cuervo.',
      Future<bool> Function(AtelierTextAnchor, String)? apply}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AtelierCommentsSheet(
      profileId: 'a',
      projectId: 'p',
      nodeId: 'n',
      service: service,
      selection: const AtelierTextAnchor(start: 0, quote: ''),
      currentText: () => text,
      apply: apply ?? (anchor, replacement) async => true,
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets('read-only collaborators cannot create or accept suggestions',
      (tester) async {
    await open(tester, _Comments()..access = ['project.read']);
    expect(find.text('Aceptar'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
        find.text('Tienes acceso de lectura a esta revisión.'), findsOneWidget);
  });
  testWidgets('live bursts refresh once and preserve a typed reply',
      (tester) async {
    final service = _Comments();
    await open(tester, service);
    await tester.enterText(
        find.byType(TextField).first, 'Mi revisión pendiente');
    final before = service.loads;
    for (var i = 0; i < 8; i++) {
      service.changes.add(null);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(service.loads, before + 1);
    expect(find.text('Mi revisión pendiente'), findsOneWidget);
    expect(service.changes.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(service.changes.hasListener, isFalse);
    await service.changes.close();
  });
  testWidgets('orphaned suggestions cannot overwrite another fragment',
      (tester) async {
    await open(tester, _Comments(), text: 'El ave.');
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Aceptar'))
            .onPressed,
        isNull);
    expect(find.textContaining('El fragmento cambió'), findsOneWidget);
  });
  testWidgets('failed saving does not resolve a suggestion', (tester) async {
    final service = _Comments();
    await open(tester, service, apply: (anchor, replacement) async => false);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(service.resolved, 0);
    expect(find.textContaining('No se pudo completar'), findsOneWidget);
  });
  testWidgets('retry resolving never reapplies an already saved suggestion',
      (tester) async {
    final service = _Comments()..failResolve = true;
    var applications = 0;
    await open(tester, service, apply: (anchor, replacement) async {
      applications++;
      return true;
    });
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    service.failResolve = false;
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(applications, 1);
    expect(service.resolved, 1);
  });
}
