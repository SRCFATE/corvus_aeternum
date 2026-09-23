import 'dart:async';
import 'package:corvus_aeternum/features/ranking/ranking_page.dart';
import 'package:corvus_aeternum/features/ranking/editorial_selection_dialog.dart';
import 'package:corvus_aeternum/models/artist_ranking.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/providers/conspiration_provider.dart';
import 'package:corvus_aeternum/services/profile_service.dart';
import 'package:corvus_aeternum/services/work_ranking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Artists extends ProfileService {
  @override
  Future<List<ArtistRankingEntry>> getArtistRanking(
          {String? discipline, int limit = 250}) async =>
      [];
}

class _Rankings extends WorkRankingService {
  final pending = <WorkRankingMode, Completer<List<WorkRankingEntry>>>{};
  String? saved;
  bool fail = true;
  @override
  Future<List<WorkRankingEntry>> load(WorkRankingMode mode,
          {String? discipline}) =>
      (pending[mode] = Completer()).future;
  @override
  Future<String?> editorialReason(String workId) async =>
      'Una selección anterior';
  @override
  Future<void> selectEditorial(String workId, String? reason) async {
    if (fail) throw StateError('offline');
    saved = reason;
  }
}

WorkRankingEntry entry(String name) => WorkRankingEntry(
    Work.fromMap({
      'id': name,
      'profile_id': 'author',
      'title': name,
      'work_type': 'text',
      'created_at': '2026-09-01',
      'updated_at': '2026-09-01',
    }),
    recentViews: 6,
    previousViews: 2);

void main() {
  testWidgets(
      'ranking modes reject stale results and remain readable on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _Rankings();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ConspirationProvider()),
        ],
        child: MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(
                    size: Size(360, 850), textScaler: TextScaler.linear(1.4)),
                child:
                    RankingPage(service: _Artists(), workService: service)))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    void select(String mode) => tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!(mode);
    select('popular');
    await tester.pump();
    select('trending');
    await tester.pump();
    service.pending[WorkRankingMode.trending]!.complete([entry('Obra actual')]);
    await tester.pumpAndSettle();
    service.pending[WorkRankingMode.popular]!
        .complete([entry('Resultado antiguo')]);
    await tester.pumpAndSettle();
    expect(find.text('Resultado antiguo'), findsNothing);
    await tester.scrollUntilVisible(find.text('Obra actual'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Obra actual'), findsOneWidget);
    expect(find.textContaining('6 visitas en 7 días'), findsOneWidget);
    expect(find.byTooltip('Leer o continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed editorial selection keeps its reason and can retry',
      (tester) async {
    final service = _Rankings();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => EditorialSelectionDialog(
                            workId: 'w', title: 'Obra', service: service)),
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'Un motivo nuevo y concreto');
    await tester.tap(find.text('Guardar selección'));
    await tester.pumpAndSettle();
    expect(find.text('Un motivo nuevo y concreto'), findsOneWidget);
    expect(find.textContaining('No se guardó'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Guardar selección'));
    await tester.pumpAndSettle();
    expect(service.saved, 'Un motivo nuevo y concreto');
    expect(find.byType(EditorialSelectionDialog), findsNothing);
  });
}
