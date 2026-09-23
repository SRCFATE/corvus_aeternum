// Local visual review: flutter run -d web-server -t tool/editorial_preview.dart.
// Uses fictional content and memory only; it never initializes Supabase.
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:corvus_aeternum/features/atelier/atelier_import_dialog.dart';
import 'package:corvus_aeternum/features/atelier/atelier_project_import.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:corvus_aeternum/core/theme/app_theme.dart';
import 'package:corvus_aeternum/features/atelier/atelier_element_editor.dart';
import 'package:corvus_aeternum/features/work/work_chapter_page.dart';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/models/work.dart';
import 'package:corvus_aeternum/providers/atelier_provider.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/services/atelier_service.dart';
import 'package:corvus_aeternum/services/work_service.dart';
import 'package:corvus_aeternum/features/ranking/ranking_page.dart';
import 'package:corvus_aeternum/services/profile_service.dart';
import 'package:corvus_aeternum/services/work_ranking_service.dart';
import 'package:corvus_aeternum/models/artist_ranking.dart';
import 'package:corvus_aeternum/providers/conspiration_provider.dart';

const _body =
    '## La biblioteca bajo la lluvia\n\nEl cuervo aguardaba en el alféizar. Al otro lado del cristal, la ciudad había olvidado su nombre.\n\n**Elena abrió el libro** y encontró una frase escrita con su propia letra: *nadie abandona el archivo sin dejar una historia*.\n\n> No eran los libros los que guardaban silencio; era la noche la que escuchaba.\n\n⁂\n\n### La primera señal\n\nUna luz recorrió el pasillo. Elena siguió sus pasos, contando las puertas que no recordaba haber visto.';
final _project = AtelierProject.fromMap({
  'id': 'preview',
  'profile_id': 'preview',
  'title': 'La ciudad sin nombre',
  'metadata': {'atelier_branch': 'writing'}
});
final _node = AtelierNode.fromMap({
  'id': 'preview-chapter',
  'profile_id': 'preview',
  'project_id': 'preview',
  'kind': 'chapter',
  'title': 'El archivo de la noche',
  'body': _body
});

class _MemoryAtelier extends AtelierService {
  AtelierNode node = _node;
  @override
  Future<AtelierWorkspace> loadWorkspace(String profileId,
          {String? projectId}) async =>
      AtelierWorkspace(
          projects: [_project],
          activeProject: _project,
          nodes: [node],
          relations: [],
          versions: []);
  @override
  Future<AtelierNode> updateNode(AtelierNode value) async => node = value;
}

class _MemoryWorks extends WorkService {
  @override
  Future<Work> getWorkById(String id) async => Work.fromMap({
        'id': id,
        'profile_id': 'preview',
        'title': 'La ciudad sin nombre',
        'text_body':
            '<!-- corvus-chapter -->\n# El archivo de la noche\n$_body',
        'created_at': '2026-09-20T00:00:00Z',
        'updated_at': '2026-09-20T00:00:00Z'
      });
}

class _MemoryArtists extends ProfileService {
  @override
  Future<List<ArtistRankingEntry>> getArtistRanking(
          {String? discipline, int limit = 250}) async =>
      [];
}

class _MemoryRanking extends WorkRankingService {
  @override
  Future<List<WorkRankingEntry>> load(WorkRankingMode mode,
          {String? discipline}) async =>
      [
        WorkRankingEntry(await _MemoryWorks().getWorkById('preview'),
            recentViews: 16,
            previousViews: 5,
            rankedAt: DateTime(2026, 9, 23),
            reason:
                'Una exploración íntima de la memoria, con una voz narrativa contenida y una atmósfera que acompaña a sus personajes.')
      ];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = AtelierProvider(service: _MemoryAtelier());
  await provider.load('preview');
  final reader = Uri.base.queryParameters['view'] == 'reader';
  final width = double.tryParse(Uri.base.queryParameters['width'] ?? '');
  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConspirationProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates:
            quill.FlutterQuillLocalizations.localizationsDelegates,
        supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
        builder: (context, child) => Center(
            child: SizedBox(
                width: width,
                child: LayoutBuilder(
                    builder: (context, constraints) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight)),
                        child: child!)))),
        home: Uri.base.queryParameters['view'] == 'ranking'
            ? RankingPage(
                service: _MemoryArtists(), workService: _MemoryRanking())
            : Uri.base.queryParameters['view'] == 'import'
                ? _ImportPreview()
                : reader
                    ? WorkChapterPage(
                        workId: 'preview',
                        initialChapter: 0,
                        service: _MemoryWorks())
                    : AtelierElementEditor(
                        profileId: 'preview',
                        projectId: 'preview',
                        initialKind: 'chapter',
                        kindLabels: const {'chapter': 'Capítulo'},
                        node: _node),
      )));
}

class _ImportPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: FilledButton(
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AtelierImportDialog(
                      project: AtelierProjectImport.parse(jsonEncode({
                        'project': {'title': 'La ciudad sin nombre'},
                        'nodes': [],
                        'relations': [],
                        'versions': [],
                      })),
                      onImport: () async {})),
              child: const Text('Recuperar proyecto de ejemplo'))));
}
