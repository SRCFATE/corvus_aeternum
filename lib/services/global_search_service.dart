import '../core/supabase_config.dart';
import '../features/work/work_reading_utils.dart';
import 'profile_service.dart';

class GlobalSearchHit {
  final String category;
  final String title;
  final String context;
  final String route;
  const GlobalSearchHit(
      {required this.category,
      required this.title,
      required this.context,
      required this.route});
}

class GlobalSearchResponse {
  final List<GlobalSearchHit> hits;
  final bool incomplete;
  const GlobalSearchResponse(this.hits, {this.incomplete = false});
}

class GlobalSearchFilters {
  final String? projectId;
  final String? status;
  final DateTime? since;
  const GlobalSearchFilters({this.projectId, this.status, this.since});
}

String globalSearchExcerpt(String body, String query) {
  body = manuscriptPlainText(body);
  final index = body.toLowerCase().indexOf(query.toLowerCase());
  final start = index < 0 ? 0 : (index - 50).clamp(0, body.length);
  return '${start > 0 ? '…' : ''}${WorkChapter(title: '', content: body.substring(start)).preview}';
}

class GlobalSearchService {
  Future<List<Map<String, dynamic>>> projects() async => await supabase
      .from('atelier_projects')
      .select('id,title')
      .isFilter('metadata->>deleted_at', null)
      .order('title')
      .limit(100);

  Future<GlobalSearchResponse> search(String query,
      {String? profileId,
      GlobalSearchFilters filters = const GlobalSearchFilters()}) async {
    if (query.trim().isEmpty) return const GlobalSearchResponse([]);
    // ilike recibe el valor como parámetro, sin interpolarlo en expresiones or.
    final escaped = query
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    var incomplete = false;
    Future<List<GlobalSearchHit>> guarded(
        Future<List<GlobalSearchHit>> Function() action) async {
      try {
        return await action();
      } catch (_) {
        incomplete = true;
        return [];
      }
    }

    final groups = await Future.wait([
      if (filters.projectId == null &&
          (filters.status == null || filters.status == 'published'))
        for (final field in ['title', 'text_body'])
          guarded(() async {
            var request = supabase
                .from('works')
                .select('id,title,text_body')
                .eq('is_public', true)
                .eq('status', 'published')
                .ilike(field, pattern);
            if (filters.since != null) {
              request = request.gte(
                  'updated_at', filters.since!.toUtc().toIso8601String());
            }
            final rows = await request.limit(8);
            return [
              for (final row in rows) ...[
                GlobalSearchHit(
                    category: 'Obras',
                    title: row['title'] as String,
                    context: globalSearchExcerpt(
                        row['text_body'] as String? ?? '', query),
                    route: '/work/${Uri.encodeComponent(row['id'] as String)}'),
                for (final chapter
                    in parseWorkChapters(row['text_body'] as String? ?? '')
                        .asMap()
                        .entries
                        .where((entry) =>
                            '${entry.value.title} ${entry.value.content}'
                                .toLowerCase()
                                .contains(query.toLowerCase()))
                        .take(4))
                  GlobalSearchHit(
                      category: 'Capítulos',
                      title: chapter.value.title.isEmpty
                          ? row['title'] as String
                          : chapter.value.title,
                      context:
                          '${row['title']} · ${globalSearchExcerpt(chapter.value.content, query)}',
                      route:
                          '/work/${Uri.encodeComponent(row['id'] as String)}/chapter/${chapter.key}'),
              ],
            ];
          }),
      if (filters.projectId == null &&
          filters.status == null &&
          filters.since == null)
        guarded(() async {
          final profiles =
              await ProfileService().getArtists(query: query, limit: 8);
          return [
            for (final profile in profiles)
              GlobalSearchHit(
                  category: 'Perfiles',
                  title: profile.displayName,
                  context: '@${profile.username}',
                  route: '/profile/${Uri.encodeComponent(profile.username)}')
          ];
        }),
      if (filters.projectId == null && filters.status == null)
        for (final field in ['title', 'description'])
          guarded(() async {
            var request = supabase
                .from('collections')
                .select('id,title,description')
                .eq('is_public', true)
                .ilike(field, pattern);
            if (filters.since != null) {
              request = request.gte(
                  'updated_at', filters.since!.toUtc().toIso8601String());
            }
            final rows = await request.limit(8);
            return [
              for (final row in rows)
                GlobalSearchHit(
                    category: 'Colecciones',
                    title: row['title'] as String,
                    context: row['description'] as String? ?? '',
                    route:
                        '/collection/${Uri.encodeComponent(row['id'] as String)}')
            ];
          }),
      if (profileId != null) ...[
        if (filters.status == null)
          guarded(() async {
            var request = supabase
                .from('atelier_projects')
                .select('id,title')
                .isFilter('metadata->>deleted_at', null)
                .ilike('title', pattern);
            if (filters.projectId != null) {
              request = request.eq('id', filters.projectId!);
            }
            if (filters.since != null) {
              request = request.gte(
                  'updated_at', filters.since!.toUtc().toIso8601String());
            }
            final rows = await request.limit(8);
            return [
              for (final row in rows)
                GlobalSearchHit(
                    category: 'Proyectos',
                    title: row['title'] as String,
                    context: 'Proyecto al que tienes acceso',
                    route: Uri(
                            path: '/atelier',
                            queryParameters: {'project': row['id'] as String})
                        .toString())
            ];
          }),
        for (final field in ['title', 'body'])
          guarded(() async {
            var request = supabase
                .from('atelier_nodes')
                .select(
                    'id,project_id,title,body,kind,metadata,atelier_projects!atelier_nodes_project_id_fkey!inner(title,metadata)')
                .isFilter('atelier_projects.metadata->>deleted_at', null)
                .isFilter('metadata->>deleted_at', null)
                .ilike(field, pattern);
            if (filters.projectId != null) {
              request = request.eq('project_id', filters.projectId!);
            }
            if (filters.status != null) {
              request = request.eq('status', filters.status!);
            }
            if (filters.since != null) {
              request = request.gte(
                  'updated_at', filters.since!.toUtc().toIso8601String());
            }
            final rows = await request.limit(30);
            return [
              for (final row in rows)
                if ((row['metadata'] as Map?)?['deleted_at'] == null)
                  GlobalSearchHit(
                      category: const {
                            'chapter': 'Capítulos',
                            'scene': 'Escenas',
                            'character': 'Personajes',
                            'place': 'Lugares'
                          }[row['kind']] ??
                          'Fichas',
                      title: row['title'] as String,
                      context:
                          '${(row['atelier_projects'] as Map?)?['title'] ?? 'Proyecto'} · ${globalSearchExcerpt(row['body'] as String? ?? '', query)}',
                      route: Uri(path: '/atelier', queryParameters: {
                        'project': row['project_id'] as String,
                        'node': row['id'] as String
                      }).toString()),
            ];
          }),
      ],
    ]);
    final unique = <String, GlobalSearchHit>{};
    for (final hit in groups.expand((group) => group)) {
      unique[hit.route] = hit;
    }
    return GlobalSearchResponse(unique.values.toList(), incomplete: incomplete);
  }
}
