import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/work.dart';
import '../models/work_comment.dart';

class WorkService {
  static const _optionalAeternumColumns = {
    'aeternum_ficha',
    'atelier_project_id',
    'root_work_id',
    'universe',
    'aeternum_status',
  };

  Future<List<Work>> getFeed({int limit = 20, int offset = 0}) async {
    final data = await supabase
        .from('works')
        .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => Work.fromMap(e)).toList();
  }

  Future<List<Work>> getDiscoverWorks({
    String? discipline,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    var q = supabase
        .from('works')
        .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
        .eq('status', 'published')
        .eq('is_public', true);

    if (discipline != null && discipline.isNotEmpty) {
      q = q.eq('discipline', discipline);
    }
    if (query != null && query.isNotEmpty) {
      q = q.ilike('title', '%$query%');
    }

    final data = await q
        .order('views_count', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => Work.fromMap(e)).toList();
  }

  Future<Work> getWorkById(String id) async {
    final data = await supabase
        .from('works')
        .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
        .eq('id', id)
        .single();
    return Work.fromMap(data);
  }

  Future<Work> createWork(Map<String, dynamic> workData) async {
    final data = await _createWorkWithOptionalFallback(workData);
    return Work.fromMap(data);
  }

  Future<Work> updateWork(String id, Map<String, dynamic> updates) async {
    final data = await _updateWorkWithOptionalFallback(id, updates);
    return Work.fromMap(data);
  }

  Future<void> deleteWork(String id) async {
    await supabase.from('works').delete().eq('id', id);
  }

  Future<void> likeWork(String userId, String workId) async {
    await supabase.from('work_likes').insert({
      'profile_id': userId,
      'work_id': workId,
    });
    await supabase
        .from('works')
        .update({'likes_count': supabase.from('works').select('likes_count')})
        .eq('id', workId)
        .catchError((_) => null);
  }

  Future<void> unlikeWork(String userId, String workId) async {
    await supabase
        .from('work_likes')
        .delete()
        .eq('profile_id', userId)
        .eq('work_id', workId);
  }

  Future<bool> isLiked(String userId, String workId) async {
    final data = await supabase
        .from('work_likes')
        .select('profile_id')
        .eq('profile_id', userId)
        .eq('work_id', workId)
        .maybeSingle();
    return data != null;
  }

  Future<bool> isSaved(String userId, String workId) async {
    final data = await supabase
        .from('saved_works')
        .select('profile_id')
        .eq('profile_id', userId)
        .eq('work_id', workId)
        .maybeSingle();
    return data != null;
  }

  Future<void> saveWork(String userId, String workId) async {
    await supabase.from('saved_works').insert({
      'profile_id': userId,
      'work_id': workId,
    });
  }

  Future<void> unsaveWork(String userId, String workId) async {
    await supabase
        .from('saved_works')
        .delete()
        .eq('profile_id', userId)
        .eq('work_id', workId);
  }

  Future<void> recordView(String workId, String? viewerId) async {
    try {
      await supabase.from('work_views').insert({
        'work_id': workId,
        if (viewerId != null) 'viewer_id': viewerId,
      });
    } catch (_) {}
  }

  Future<List<WorkComment>> getComments(String workId) async {
    final data = await supabase
        .from('work_comments')
        .select(
            '*, profiles!work_comments_profile_id_fkey(username, display_name, avatar_url)')
        .eq('work_id', workId)
        .eq('is_deleted', false)
        .isFilter('parent_id', null)
        .order('created_at', ascending: true);
    return (data as List).map((e) => WorkComment.fromMap(e)).toList();
  }

  Future<WorkComment> addComment(
      String workId, String profileId, String body) async {
    final data = await supabase
        .from('work_comments')
        .insert({
          'work_id': workId,
          'profile_id': profileId,
          'body': body,
        })
        .select(
            '*, profiles!work_comments_profile_id_fkey(username, display_name, avatar_url)')
        .single();
    return WorkComment.fromMap(data);
  }

  Future<List<Work>> getWorksByProfile(String profileId,
      {int limit = 6, String? excludeId}) async {
    final data = await supabase
        .from('works')
        .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
        .eq('profile_id', profileId)
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(limit + 1);
    return (data as List)
        .map((e) => Work.fromMap(e))
        .where((w) => w.id != excludeId)
        .take(limit)
        .toList();
  }

  Future<List<Work>> getOwnWorks(String profileId, {int limit = 500}) async {
    final data = await supabase
        .from('works')
        .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
        .eq('profile_id', profileId)
        .order('updated_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Work.fromMap(e)).toList();
  }

  Future<List<Work>> getSavedWorks(String userId) async {
    final data = await supabase
        .from('saved_works')
        .select(
            'works(*, profiles!works_profile_id_fkey(username, display_name, avatar_url))')
        .eq('profile_id', userId)
        .order('saved_at', ascending: false);

    return (data as List)
        .where((e) => e['works'] != null)
        .map((e) => Work.fromMap(e['works'] as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _createWorkWithOptionalFallback(
    Map<String, dynamic> workData,
  ) async {
    try {
      return await supabase
          .from('works')
          .insert(workData)
          .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)',
          )
          .single();
    } catch (error) {
      if (!_canRetryWithoutAeternumColumns(error, workData)) rethrow;
      return await supabase
          .from('works')
          .insert(
            _withoutAeternumColumns(workData),
          )
          .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)',
          )
          .single();
    }
  }

  Future<Map<String, dynamic>> _updateWorkWithOptionalFallback(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final payload = {
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      return await supabase
          .from('works')
          .update(payload)
          .eq('id', id)
          .select(
              '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
          .single();
    } catch (error) {
      if (!_canRetryWithoutAeternumColumns(error, payload)) rethrow;
      return await supabase
          .from('works')
          .update(_withoutAeternumColumns(payload))
          .eq('id', id)
          .select(
              '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
          .single();
    }
  }

  bool _canRetryWithoutAeternumColumns(
    Object error,
    Map<String, dynamic> payload,
  ) {
    if (!payload.keys.any(_optionalAeternumColumns.contains)) return false;
    return _looksLikeMissingOptionalColumn(error);
  }

  bool _looksLikeMissingOptionalColumn(Object error) {
    final message = error is PostgrestException
        ? '${error.code ?? ''} ${error.message}'.toLowerCase()
        : error.toString().toLowerCase();
    if (!message.contains('column') && !message.contains('schema cache')) {
      return false;
    }
    return _optionalAeternumColumns.any(message.contains);
  }

  Map<String, dynamic> _withoutAeternumColumns(Map<String, dynamic> payload) {
    return Map<String, dynamic>.from(payload)
      ..removeWhere((key, _) => _optionalAeternumColumns.contains(key));
  }
}
