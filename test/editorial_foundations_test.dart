import 'dart:async';
import 'package:corvus_aeternum/features/atelier/atelier_document_outline.dart';
import 'package:corvus_aeternum/features/atelier/atelier_manuscript_navigator.dart';
import 'package:corvus_aeternum/features/atelier/atelier_writing_progress.dart';
import 'package:corvus_aeternum/features/atelier/atelier_publication_review.dart';
import 'package:corvus_aeternum/features/home/global_search_dialog.dart';
import 'package:corvus_aeternum/features/work/reader_preferences.dart';
import 'package:corvus_aeternum/models/atelier_comment.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/services/global_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Search extends GlobalSearchService {
  final pending = <String, Completer<GlobalSearchResponse>>{};
  @override
  Future<GlobalSearchResponse> search(String query,
          {String? profileId,
          GlobalSearchFilters filters = const GlobalSearchFilters()}) =>
      (pending[query] = Completer()).future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('weekly writing progress rolls over on Monday and ignores deletions',
      () {
    final sunday = DateTime(2026, 9, 20, 23, 59);
    final monday = DateTime(2026, 9, 21);
    final first = recordWritingProgress({'purpose': 'Clímax'},
        before: 100, after: 130, now: sunday);
    expect(first['writing_words'], 30);
    expect(first['purpose'], 'Clímax');
    final trimmed =
        recordWritingProgress(first, before: 130, after: 90, now: sunday);
    expect(trimmed['writing_words'], 30);
    final next =
        recordWritingProgress(trimmed, before: 90, after: 95, now: monday);
    expect(next['writing_words'], 5);
    expect(next['writing_week'], '2026-09-21');
  });

  testWidgets(
      'manuscript index collapses children and opens search by keyboard',
      (tester) async {
    AtelierNavigationTarget? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result =
                            await showModalBottomSheet<AtelierNavigationTarget>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) =>
                                    const AtelierManuscriptNavigator(
                                      headings: [
                                        AtelierHeading('Parte', 1, 0),
                                        AtelierHeading('Detalle', 2, 6),
                                        AtelierHeading('Final', 1, 20)
                                      ],
                                      text: 'Eco primero. Eco segundo.',
                                    ));
                      },
                      child: const Text('Abrir')),
                ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Contraer sección'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle'), findsNothing);
    expect(find.text('Final'), findsOneWidget);
    await tester.tap(find.byTooltip('Expandir sección'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Eco');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('2 de 2 coincidencias'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result?.offset, 13);
    expect(result?.query, 'Eco');
  });
  test('outline offsets survive inline formatting and do not create chapters',
      () {
    final outline = atelierDocumentOutline([
      {'insert': 'Entrada\n'},
      {
        'insert': 'Una ',
        'attributes': {'bold': true}
      },
      {'insert': 'sección'},
      {
        'insert': '\n',
        'attributes': {'header': 2}
      },
      {'insert': 'Texto\n'},
    ]);
    expect(outline.single.title, 'Una sección');
    expect(outline.single.offset, 8);
    expect(outline.single.level, 2);
    expect(atelierFindOccurrences('Eco eco ECO', 'eco'), [0, 4, 8]);
    expect(atelierFindOccurrences('Eco', ''), isEmpty);
    expect(atelierFindOccurrences('İ 🎭 eco ECO', 'eco'), [5, 9]);
    expect(atelierFindOccurrences('a.b aXb', 'a.b'), [0]);
  });

  test(
      'publication blocks empty elements, allows recommendations and hides markup in counts',
      () {
    final node = AtelierNode(
        id: 'one',
        projectId: 'p',
        profileId: 'a',
        kind: 'chapter',
        title: 'Capítulo',
        body: '<!-- corvus-align:center -->\n# Subtítulo\n**Dos palabras**',
        status: 'draft',
        canonStatus: 'canon',
        visibility: 'private',
        tags: const [],
        metadata: const {},
        position: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026));
    expect(node.wordCount, 3);
    final valid = reviewAtelierPublication([node]);
    expect(valid.any((issue) => issue.severity == PublicationSeverity.blocking),
        isFalse);
    expect(
        valid.any(
            (issue) => issue.severity == PublicationSeverity.recommendation),
        isTrue);
    expect(
        reviewAtelierPublication([node.copyWith(body: '')])
            .any((issue) => issue.severity == PublicationSeverity.blocking),
        isTrue);
  });

  test(
      'comment anchor follows insertions and refuses ambiguous or deleted text',
      () {
    final anchor =
        AtelierTextAnchor.capture('Antes del cuervo. Después.', 10, 16);
    expect(anchor.quote, 'cuervo');
    expect(anchor.locate('Nuevo. Antes del cuervo. Después.'), 17);
    expect(anchor.locate('Antes del ave. Después.'), isNull);
    expect(const AtelierTextAnchor(start: 0, quote: 'eco').locate('eco eco'),
        isNull);
    expect(AtelierTextAnchor.fromMap(anchor.toMap()).quote, anchor.quote);
  });

  test('reader preferences clamp corrupted values and round trip', () {
    final prefs = ReaderPreferences.fromMap(
        {'fontSize': 500, 'width': -20, 'palette': 'unknown'});
    expect(prefs.fontSize, 30);
    expect(prefs.width, 650);
    expect(prefs.palette, ReaderPalette.dark);
    final restored = ReaderPreferences.fromMap(
        const ReaderPreferences(palette: ReaderPalette.sepia, serif: false)
            .toMap());
    expect(restored.palette, ReaderPalette.sepia);
    expect(restored.serif, false);
  });

  testWidgets('global search rejects obsolete results and opens with keyboard',
      (tester) async {
    final service = _Search();
    String? route;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GlobalSearchDialog(
                service: service, onNavigate: (value) => route = value))));
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await tester.enterText(input, 'viejo');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(input, 'nuevo');
    await tester.pump(const Duration(milliseconds: 350));
    service.pending['nuevo']!.complete(const GlobalSearchResponse([
      GlobalSearchHit(
          category: 'Capítulos',
          title: 'Nuevo capítulo',
          context: 'Mi proyecto',
          route: '/atelier?project=p&node=n')
    ]));
    await tester.pumpAndSettle();
    service.pending['viejo']!.complete(const GlobalSearchResponse([
      GlobalSearchHit(
          category: 'Obras',
          title: 'Viejo resultado',
          context: '',
          route: '/work/old')
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo capítulo'), findsOneWidget);
    expect(find.text('Viejo resultado'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(route, '/atelier?project=p&node=n');
  });
}
