import '../core/supabase_config.dart';
import '../models/collection.dart';
import '../models/work.dart';

class CollectionService {
  static const _collectionSelect =
      '*, profiles!collections_profile_id_fkey(username, display_name, avatar_url)';
  static const _itemSelect =
      '*, works(*, profiles!works_profile_id_fkey(username, display_name, avatar_url))';

  Future<List<Collection>> getCollections({
    String? profileId,
    bool publicOnly = true,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = supabase.from('collections').select(_collectionSelect);

    if (profileId != null) {
      query = query.eq('profile_id', profileId);
    }
    if (publicOnly) {
      query = query.eq('is_public', true);
    }

    final data = await query
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .map((item) => Collection.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Collection>> getFeaturedCollections({int limit = 12}) async {
    final data = await supabase
        .from('collections')
        .select(_collectionSelect)
        .eq('is_featured', true)
        .eq('is_public', true)
        .order('updated_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((item) => Collection.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Collection> getCollectionById(String id) async {
    final data = await supabase
        .from('collections')
        .select(_collectionSelect)
        .eq('id', id)
        .single();
    return Collection.fromMap(data);
  }

  Future<Collection> createCollection({
    required String profileId,
    required String title,
    required String description,
    required bool isPublic,
    List<String> tags = const [],
    String? coverUrl,
    String collectionType = 'curated',
    String curatorName = 'Corvus',
  }) async {
    final data = await supabase
        .from('collections')
        .insert({
          'profile_id': profileId,
          'curator_name':
              curatorName.trim().isEmpty ? 'Corvus' : curatorName.trim(),
          'title': title.trim(),
          'description': description.trim(),
          'is_public': isPublic,
          'collection_type': collectionType,
          'tags': tags,
          if (coverUrl != null && coverUrl.trim().isNotEmpty)
            'cover_url': coverUrl.trim(),
        })
        .select(_collectionSelect)
        .single();
    return Collection.fromMap(data);
  }

  Future<Collection> updateCollection({
    required String id,
    required String title,
    required String description,
    required bool isPublic,
    required String collectionType,
    required List<String> tags,
    String? coverUrl,
  }) async {
    final data = await supabase
        .from('collections')
        .update({
          'title': title.trim(),
          'description': description.trim(),
          'is_public': isPublic,
          'collection_type': collectionType,
          'tags': tags,
          'cover_url':
              coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_collectionSelect)
        .single();
    return Collection.fromMap(data);
  }

  Future<void> deleteCollection(String id) async {
    await supabase.from('collections').delete().eq('id', id);
  }

  Future<List<CollectionItem>> getCollectionItems(String collectionId) async {
    final data = await supabase
        .from('collection_items')
        .select(_itemSelect)
        .eq('collection_id', collectionId)
        .order('position', ascending: true)
        .order('added_at', ascending: true);

    return (data as List)
        .map((item) => CollectionItem.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.work != null)
        .toList();
  }

  Future<List<Work>> getCollectionWorks(String collectionId) async {
    final items = await getCollectionItems(collectionId);
    return items.map((item) => item.work!).toList();
  }

  Future<void> addWorkToCollection(
    String collectionId,
    String workId, {
    String note = '',
  }) async {
    final last = await supabase
        .from('collection_items')
        .select('position')
        .eq('collection_id', collectionId)
        .order('position', ascending: false)
        .limit(1)
        .maybeSingle();
    final nextPosition = ((last?['position'] as int?) ?? -1) + 1;

    await supabase.from('collection_items').upsert({
      'collection_id': collectionId,
      'work_id': workId,
      'position': nextPosition,
      'note': note.trim(),
      if (supabase.auth.currentUser != null)
        'added_by': supabase.auth.currentUser!.id,
    }, onConflict: 'collection_id,work_id', ignoreDuplicates: true);
  }

  Future<void> addWorksToCollection(
    String collectionId,
    List<String> workIds,
  ) async {
    final uniqueWorkIds = workIds.toSet().toList();
    if (uniqueWorkIds.isEmpty) return;

    final last = await supabase
        .from('collection_items')
        .select('position')
        .eq('collection_id', collectionId)
        .order('position', ascending: false)
        .limit(1)
        .maybeSingle();
    final firstPosition = ((last?['position'] as int?) ?? -1) + 1;
    final addedBy = supabase.auth.currentUser?.id;

    await supabase.from('collection_items').upsert(
          List.generate(uniqueWorkIds.length, (index) {
            return {
              'collection_id': collectionId,
              'work_id': uniqueWorkIds[index],
              'position': firstPosition + index,
              'note': '',
              if (addedBy != null) 'added_by': addedBy,
            };
          }),
          onConflict: 'collection_id,work_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> updateCollectionItem({
    required String collectionId,
    required String workId,
    required String note,
  }) async {
    await supabase
        .from('collection_items')
        .update({'note': note.trim()})
        .eq('collection_id', collectionId)
        .eq('work_id', workId);
  }

  Future<void> reorderCollectionItems({
    required String collectionId,
    required List<String> workIds,
  }) async {
    await supabase.rpc('reorder_collection_items', params: {
      'p_collection_id': collectionId,
      'p_work_ids': workIds,
    });
  }

  Future<void> removeWorkFromCollection(
    String collectionId,
    String workId,
  ) async {
    await supabase
        .from('collection_items')
        .delete()
        .eq('collection_id', collectionId)
        .eq('work_id', workId);
  }

  Future<Set<String>> getCollectionIdsForWork(
    String workId,
    List<String> collectionIds,
  ) async {
    if (collectionIds.isEmpty) return <String>{};
    final data = await supabase
        .from('collection_items')
        .select('collection_id')
        .eq('work_id', workId)
        .inFilter('collection_id', collectionIds);
    return (data as List)
        .map((item) => item['collection_id'] as String)
        .toSet();
  }

  Future<Map<String, String>> getPrivateNotes(String collectionId) async {
    final data = await supabase
        .from('collection_private_notes')
        .select('work_id, note')
        .eq('collection_id', collectionId);
    return {
      for (final item in data as List)
        item['work_id'] as String: item['note'] as String? ?? '',
    };
  }

  Future<void> updatePrivateNote({
    required String collectionId,
    required String workId,
    required String profileId,
    required String note,
  }) async {
    final normalized = note.trim();
    if (normalized.isEmpty) {
      await supabase
          .from('collection_private_notes')
          .delete()
          .eq('collection_id', collectionId)
          .eq('work_id', workId);
      return;
    }
    await supabase.from('collection_private_notes').upsert({
      'collection_id': collectionId,
      'work_id': workId,
      'profile_id': profileId,
      'note': normalized,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'collection_id,work_id');
  }

  Future<List<Collection>> getUserCollections(String profileId) async {
    return getCollections(profileId: profileId, publicOnly: false, limit: 100);
  }

  Future<bool> workInCollection(String collectionId, String workId) async {
    final data = await supabase
        .from('collection_items')
        .select('collection_id')
        .eq('collection_id', collectionId)
        .eq('work_id', workId)
        .maybeSingle();
    return data != null;
  }

  Future<bool> isLiked(String collectionId, String profileId) async {
    final data = await supabase
        .from('collection_likes')
        .select('collection_id')
        .eq('collection_id', collectionId)
        .eq('profile_id', profileId)
        .maybeSingle();
    return data != null;
  }

  Future<void> likeCollection(String collectionId, String profileId) async {
    await supabase.from('collection_likes').upsert({
      'collection_id': collectionId,
      'profile_id': profileId,
    }, onConflict: 'collection_id,profile_id', ignoreDuplicates: true);
  }

  Future<void> unlikeCollection(String collectionId, String profileId) async {
    await supabase
        .from('collection_likes')
        .delete()
        .eq('collection_id', collectionId)
        .eq('profile_id', profileId);
  }

  Future<void> recordView(String collectionId, String profileId) async {
    try {
      await supabase.from('collection_views').upsert({
        'collection_id': collectionId,
        'profile_id': profileId,
      }, onConflict: 'collection_id,profile_id', ignoreDuplicates: true);
    } catch (_) {}
  }
}
