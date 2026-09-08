import 'package:corvus_aeternum/features/atelier/atelier_publication_text.dart';
import 'package:corvus_aeternum/features/atelier/atelier_rich_text_editor.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:corvus_aeternum/services/atelier_service.dart';
import 'package:corvus_aeternum/shared/widgets/formatted_manuscript_text.dart';
import 'package:corvus_aeternum/features/work/work_reading_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visual editor applies inline and block formatting to a selection', () {
    final controller = AtelierRichTextController(text: 'Una revelacion');
    addTearDown(controller.dispose);

    controller.selection = const TextSelection(baseOffset: 4, extentOffset: 14);
    controller.toggleInline('**');
    expect(controller.text, 'Una **revelacion**');

    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    controller.toggleBlock('> ');
    expect(controller.text, '> Una **revelacion**');
  });

  test('published manuscript carries each node alignment', () {
    final body = composeAtelierPublicationText([
      _node(metadata: const {'text_alignment': 'justify'}),
    ]);

    expect(body, contains('<!-- corvus-align:justify -->'));
    expect(body, contains('# Prologo'));
  });

  test('published node boundaries do not split its internal headings', () {
    final body = composeAtelierPublicationText([
      _node(body: '## Con los ojos vendados\n\nTexto narrativo.'),
    ]);
    final chapters = parseWorkChapters(body);

    expect(body, startsWith('<!-- corvus-chapter -->'));
    expect(chapters, hasLength(1));
    expect(chapters.single.title, 'Prologo');
    expect(chapters.single.content, contains('## Con los ojos vendados'));
  });

  testWidgets('visual controller renders formatted text inside an editor',
      (tester) async {
    final controller = AtelierRichTextController(
      text: '# Titulo\n\nUn **secreto**\n- Elemento',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: TextField(controller: controller, maxLines: 8)),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('reader consumes alignment directive without displaying it',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: FormattedManuscriptText(
            text: '<!-- corvus-align:center -->\nTexto centrado',
          ),
        ),
      ),
    );

    expect(find.textContaining('corvus-align'), findsNothing);
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.textAlign, TextAlign.center);
  });

  testWidgets('reader preserves combined inline formatting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: FormattedManuscriptText(
            text: '**_Combinado_** y <u>subrayado</u>',
          ),
        ),
      ),
    );

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final combined = _spanWithText(text.textSpan!, 'Combinado');
    final underlined = _spanWithText(text.textSpan!, 'subrayado');
    expect(combined?.style?.fontWeight, FontWeight.w900);
    expect(combined?.style?.fontStyle, FontStyle.italic);
    expect(underlined?.style?.decoration, TextDecoration.underline);
  });

  testWidgets('reader renders legacy horizontal rules without visible markup',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: FormattedManuscriptText(
            text: 'Antes\n\n- - -\n\nDespués',
          ),
        ),
      ),
    );

    expect(find.text('- - -'), findsNothing);
    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('Después'), findsOneWidget);
  });

  test('marking a linked chapter done updates its published work', () async {
    final node = _node();
    final project = _project(
      metadata: const {'publication_work_id': 'work-1'},
    );
    final service = _FakeAtelierService(
      AtelierWorkspace(
        projects: [project],
        activeProject: project,
        nodes: [node],
        relations: const [],
        versions: const [],
      ),
    );
    final provider = AtelierProvider(service: service);
    await provider.load('profile-1');

    final result = await provider.updateNode(
      node.copyWith(body: 'Corregido', status: 'done'),
    );

    expect(result.publicationLinked, isTrue);
    expect(result.publicationSynced, isTrue);
    expect(service.syncCalls, 1);
    expect(service.syncedNodes.single.body, 'Corregido');
    expect(service.syncedNodes.single.status, 'done');
  });
}

TextSpan? _spanWithText(InlineSpan span, String value) {
  if (span is! TextSpan) return null;
  if (span.text == value) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final result = _spanWithText(child, value);
    if (result != null) return result;
  }
  return null;
}

AtelierNode _node({
  Map<String, dynamic> metadata = const {},
  String body = 'Texto original',
}) {
  return AtelierNode(
    id: 'node-1',
    projectId: 'project-1',
    profileId: 'profile-1',
    kind: 'chapter',
    title: 'Prologo',
    body: body,
    status: 'active',
    canonStatus: 'canon',
    visibility: 'private',
    tags: const [],
    metadata: metadata,
    position: 0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

AtelierProject _project({Map<String, dynamic> metadata = const {}}) {
  return AtelierProject(
    id: 'project-1',
    profileId: 'profile-1',
    title: 'Obra',
    type: 'Novela',
    status: 'borrador',
    genre: 'Fantasia',
    universe: '',
    language: 'es',
    visibility: 'private',
    weeklyWordGoal: 0,
    publicProgressEnabled: false,
    metadata: metadata,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeAtelierService extends AtelierService {
  final AtelierWorkspace seededWorkspace;
  int syncCalls = 0;
  List<AtelierNode> syncedNodes = const [];

  _FakeAtelierService(this.seededWorkspace);

  @override
  Future<AtelierWorkspace> loadWorkspace(
    String profileId, {
    String? projectId,
  }) async {
    return seededWorkspace;
  }

  @override
  Future<AtelierNode> updateNode(AtelierNode node) async => node;

  @override
  Future<({int chapters, bool isPublished, String workId})?> syncPublishedWork({
    required AtelierProject project,
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
    required List<AtelierVersion> versions,
  }) async {
    syncCalls++;
    syncedNodes = nodes;
    return (workId: 'work-1', chapters: nodes.length, isPublished: true);
  }
}
