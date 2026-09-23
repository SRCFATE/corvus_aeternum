import '../core/supabase_config.dart';
import '../models/work.dart';

enum WorkRankingMode {
  popular('Popularidad', 'popular',
      'Me gusta acumulados; en empate, visitas acumuladas. No mide calidad editorial.'),
  editorial('Selección editorial', 'editorial',
      'Obras elegidas por el equipo editorial con un motivo visible. Las elecciones más recientes aparecen primero.'),
  trending('Tendencia', 'trending',
      'Crecimiento de visitas en los últimos 7 días frente a los 7 anteriores. Al menos 3 visitas recientes; solo crecimiento positivo.'),
  active('Actividad', 'active',
      'Publicaciones públicas más recientes. Las visitas y los Me gusta no cambian este orden.');

  final String label;
  final String value;
  final String explanation;
  const WorkRankingMode(this.label, this.value, this.explanation);
}

class WorkRankingEntry {
  final Work work;
  final int recentViews;
  final int previousViews;
  final String? reason;
  final DateTime? rankedAt;
  const WorkRankingEntry(this.work,
      {this.recentViews = 0,
      this.previousViews = 0,
      this.reason,
      this.rankedAt});

  String context(WorkRankingMode mode) => switch (mode) {
        WorkRankingMode.popular =>
          '${work.likesCount} Me gusta · ${work.viewsCount} visitas acumuladas',
        WorkRankingMode.editorial => reason ?? 'Selección del equipo editorial',
        WorkRankingMode.trending =>
          '$recentViews visitas en 7 días · $previousViews en los 7 anteriores',
        WorkRankingMode.active => rankedAt == null
            ? 'Publicación reciente'
            : 'Publicada el ${rankedAt!.toLocal().day}/${rankedAt!.toLocal().month}/${rankedAt!.toLocal().year}',
      };
}

class WorkRankingService {
  Future<List<WorkRankingEntry>> load(WorkRankingMode mode,
      {String? discipline}) async {
    final ranking = List<Map<String, dynamic>>.from(await supabase
        .rpc('public_work_rankings', params: {
      'p_mode': mode.value,
      'p_discipline': discipline,
      'p_limit': 40
    }));
    if (ranking.isEmpty) return [];
    final rows = await supabase
        .from('works')
        .select(
            'id,profile_id,title,discipline,cover_url,media_urls,likes_count,'
            'views_count,status,is_public,work_type,created_at,updated_at,'
            'profiles!works_profile_id_fkey(username,display_name,avatar_url)')
        .inFilter('id', ranking.map((row) => row['work_id']).toList())
        .eq('is_public', true)
        .eq('status', 'published');
    final works = {for (final row in rows) row['id']: Work.fromMap(row)};
    return [
      for (final row in ranking)
        if (works[row['work_id']] case final Work work)
          WorkRankingEntry(work,
              recentViews: (row['recent_views'] as num?)?.toInt() ?? 0,
              previousViews: (row['previous_views'] as num?)?.toInt() ?? 0,
              reason: row['editorial_reason'] as String?,
              rankedAt: DateTime.tryParse(row['ranked_at'] as String? ?? ''))
    ];
  }

  Future<String?> editorialReason(String workId) async {
    final row = await supabase
        .from('editorial_work_selections')
        .select('reason')
        .eq('work_id', workId)
        .maybeSingle();
    return row?['reason'] as String?;
  }

  Future<void> selectEditorial(String workId, String? reason) async {
    if (reason == null) {
      await supabase
          .from('editorial_work_selections')
          .delete()
          .eq('work_id', workId);
    } else {
      await supabase.from('editorial_work_selections').upsert({
        'work_id': workId,
        'reason': reason.trim(),
        'selected_at': DateTime.now().toUtc().toIso8601String()
      });
    }
  }
}
