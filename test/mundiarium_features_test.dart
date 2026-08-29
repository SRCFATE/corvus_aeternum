import 'package:corvus_aeternum/features/atelier/character_editor_page.dart';
import 'package:corvus_aeternum/features/atelier/mundiarium_workspace.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final character = _node(
    id: 'character-1',
    kind: 'character',
    title: 'Serafina Vale',
    body: '# Heredera\nCustodia el archivo de la casa.',
    metadata: const {
      'character_template': 'narrative',
      'character_sheet': {
        'role': 'Protagonista',
        'desire': 'Recuperar el archivo perdido',
      },
      'character_timeline': [
        {
          'id': 'moment-1',
          'date': 'Ano 12',
          'title': 'El exilio',
          'description': '**Pierde** su nombre y abandona la capital.',
        },
      ],
    },
  );
  final place = _node(
    id: 'place-1',
    kind: 'place',
    title: 'Torre del Archivo',
  );
  final relation = AtelierRelation(
    id: 'relation-1',
    projectId: 'project-1',
    profileId: 'profile-1',
    sourceNodeId: character.id,
    relationType: 'custodia',
    targetNodeId: place.id,
    description: '',
    canonStatus: 'canon',
    createdAt: DateTime(2026),
  );

  test('reads persisted character sheet and timeline metadata', () {
    expect(characterSheet(character)['role'], 'Protagonista');
    expect(characterTimeline(character).single['title'], 'El exilio');
  });

  testWidgets('character editor exposes templates and timeline on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AtelierProvider(),
        child: MaterialApp(
          home: CharacterEditorPage(
            profileId: 'profile-1',
            projectId: 'project-1',
            node: character,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Plantilla de ficha'), findsOneWidget);
    expect(find.text('Esencial'), findsOneWidget);
    expect(find.text('Narrativa'), findsOneWidget);
    expect(find.text('Completa'), findsOneWidget);
    expect(find.text('Linea de tiempo'), findsOneWidget);
    expect(find.text('El exilio'), findsOneWidget);

    await tester.ensureVisible(find.text('Completa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completa'));
    await tester.pump();
    expect(find.text('Presencia y mundo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mundiarium switches between map, timeline and character views',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _SeededAtelierProvider(
      nodes: [character, place],
      relations: [relation],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MundiariumWorkspace(
              accent: Colors.red,
              atelier: provider,
              onCreateUniverse: () {},
              onCreateNode: (_) {},
              onEditNode: (_) {},
              onDeleteNode: (_) {},
              onCreateRelation: () {},
              onDeleteRelation: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Indice'), findsOneWidget);
    expect(find.text('Serafina Vale'), findsOneWidget);

    await tester.tap(find.text('Universos'));
    await tester.pump();
    expect(find.text('Universos creativos'), findsOneWidget);
    expect(find.text('Crear universo'), findsOneWidget);

    await tester.tap(find.text('Mapa'));
    await tester.pump();
    expect(find.text('Mapa de relaciones'), findsOneWidget);
    expect(find.text('Torre del Archivo'), findsOneWidget);
    await tester.tap(find.text('Serafina Vale'));
    await tester.pump();
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);

    await tester.tap(find.text('Cronologia'));
    await tester.pump();
    expect(find.text('Cronologias de personajes'), findsOneWidget);
    expect(find.text('El exilio'), findsOneWidget);

    await tester.tap(find.text('Personajes'));
    await tester.pump();
    expect(find.text('Fichas de personaje'), findsOneWidget);
    expect(find.text('Protagonista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('relationship map keeps dense nodes stable on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nodes = List.generate(
      12,
      (index) => _node(
        id: 'node-$index',
        kind: index.isEven ? 'character' : 'place',
        title: 'Entidad $index',
      ),
    );
    final relations = List.generate(
      11,
      (index) => AtelierRelation(
        id: 'relation-$index',
        projectId: 'project-1',
        profileId: 'profile-1',
        sourceNodeId: nodes[index].id,
        relationType: 'conoce',
        targetNodeId: nodes[index + 1].id,
        description: '',
        canonStatus: 'canon',
        createdAt: DateTime(2026),
      ),
    );
    final provider = _SeededAtelierProvider(
      nodes: nodes,
      relations: relations,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MundiariumWorkspace(
              accent: Colors.red,
              atelier: provider,
              onCreateUniverse: () {},
              onCreateNode: (_) {},
              onEditNode: (_) {},
              onDeleteNode: (_) {},
              onCreateRelation: () {},
              onDeleteRelation: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mapa'));
    await tester.pump();
    expect(find.text('Mapa de relaciones'), findsOneWidget);
    expect(find.text('Entidad 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AtelierNode _node({
  required String id,
  required String kind,
  required String title,
  String body = '',
  Map<String, dynamic> metadata = const {},
}) {
  return AtelierNode(
    id: id,
    projectId: 'project-1',
    profileId: 'profile-1',
    kind: kind,
    title: title,
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

class _SeededAtelierProvider extends AtelierProvider {
  final List<AtelierNode> seededNodes;
  final List<AtelierRelation> seededRelations;

  _SeededAtelierProvider({
    required List<AtelierNode> nodes,
    required List<AtelierRelation> relations,
  })  : seededNodes = nodes,
        seededRelations = relations;

  @override
  List<AtelierNode> get nodes => seededNodes;

  @override
  List<AtelierRelation> get relations => seededRelations;
}
