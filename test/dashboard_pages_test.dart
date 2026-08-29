import 'package:corvus_aeternum/features/insights/insights_page.dart';
import 'package:corvus_aeternum/features/planner/planner_page.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/models/creative_insights.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creative insights renders on desktop and mobile',
      (tester) async {
    final project = _project();
    final insights = CreativeInsights.fromData(
      works: [_work()],
      projects: [project],
      collections: const [],
    );

    await _pumpAtSize(
      tester,
      const Size(1280, 900),
      InsightsPage(initialInsights: insights),
    );
    expect(find.text('Pulso creativo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpAtSize(
      tester,
      const Size(390, 844),
      InsightsPage(initialInsights: insights),
    );
    expect(find.text('Obras terminadas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner renders both calendar and journal on mobile',
      (tester) async {
    final project = _project();
    final workspace = AtelierPlannerWorkspace(
      projects: [project],
      entries: [
        _plannerEntry(
          id: 'task',
          kind: 'task',
          metadata: const {'scheduled_for': '2026-08-16'},
        ),
        _plannerEntry(
          id: 'journal',
          kind: 'journal',
          metadata: const {'journal_date': '2026-08-16'},
        ),
      ],
    );

    await _pumpAtSize(
      tester,
      const Size(390, 844),
      PlannerPage(initialWorkspace: workspace),
    );
    expect(find.text('Calendario y diario'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Diario'));
    await tester.pumpAndSettle();
    expect(find.text('Diario del artista'), findsOneWidget);
    expect(find.text('Registro journal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Work _work() {
  return Work.fromMap({
    'id': 'work',
    'profile_id': 'profile',
    'title': 'Nocturno IV',
    'description': '',
    'discipline': 'Pintura',
    'subdiscipline': '',
    'medium': '',
    'status': 'published',
    'is_public': true,
    'is_complete': true,
    'views_count': 120,
    'likes_count': 12,
    'saves_count': 4,
    'created_at': '2026-08-01T00:00:00.000Z',
    'updated_at': '2026-08-01T00:00:00.000Z',
  });
}

AtelierProject _project() {
  final now = DateTime.utc(2026, 8, 16);
  return AtelierProject(
    id: 'project',
    profileId: 'profile',
    title: 'Distrito 404',
    type: 'Novela',
    status: 'desarrollo',
    genre: 'Cyberpunk',
    universe: 'Nuevo Anahuac',
    language: 'es',
    visibility: 'private',
    weeklyWordGoal: 2000,
    publicProgressEnabled: false,
    metadata: const {'progress': 64},
    createdAt: now,
    updatedAt: now,
  );
}

AtelierPlannerEntry _plannerEntry({
  required String id,
  required String kind,
  required Map<String, dynamic> metadata,
}) {
  return AtelierPlannerEntry.fromMap({
    'id': id,
    'project_id': 'project',
    'profile_id': 'profile',
    'kind': kind,
    'title': 'Registro $id',
    'body': 'Una nota del proceso creativo.',
    'status': 'draft',
    'metadata': metadata,
    'created_at': '2026-08-16T00:00:00.000Z',
    'updated_at': '2026-08-16T00:00:00.000Z',
    'atelier_projects': {'title': 'Distrito 404', 'type': 'Novela'},
  });
}
