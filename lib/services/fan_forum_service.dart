import '../core/supabase_config.dart';
import '../models/fan_forum.dart';
import '../models/work.dart';

const _forumSelect = '''
  *,
  owner:profiles!fan_forums_owner_id_fkey(
    id, username, display_name, avatar_url
  ),
  linked_work:works!fan_forums_linked_work_id_fkey(
    id, title, cover_url
  )
''';

const _membershipSelect = '''
  *,
  profile:profiles!fan_forum_members_profile_id_fkey(
    id, username, display_name, avatar_url
  )
''';

const _threadSelect = '''
  *,
  author:profiles!fan_forum_threads_author_id_fkey(
    id, username, display_name, avatar_url
  )
''';

const _replySelect = '''
  *,
  author:profiles!fan_forum_replies_author_id_fkey(
    id, username, display_name, avatar_url
  )
''';

class FanForumService {
  String? get currentProfileId => supabase.auth.currentUser?.id;

  Future<bool> canCreateForum() async {
    final profileId = currentProfileId;
    if (profileId == null) return false;
    final rows = await supabase
        .from('works')
        .select('id')
        .eq('profile_id', profileId)
        .eq('status', 'published')
        .eq('is_public', true)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<List<Work>> getAuthorWorks() async {
    final profileId = currentProfileId;
    if (profileId == null) return const [];
    final rows = await supabase
        .from('works')
        .select()
        .eq('profile_id', profileId)
        .eq('status', 'published')
        .eq('is_public', true)
        .order('published_at', ascending: false);
    return (rows as List)
        .map((row) => Work.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<FanForum>> getForums() async {
    final rows = await supabase
        .from('fan_forums')
        .select(_forumSelect)
        .eq('status', 'active')
        .order('last_activity_at', ascending: false);
    final forums = (rows as List)
        .map((row) => FanForum.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
    return _attachMemberships(forums);
  }

  Future<FanForum?> getForum(String forumId) async {
    final row = await supabase
        .from('fan_forums')
        .select(_forumSelect)
        .eq('id', forumId)
        .maybeSingle();
    if (row == null) return null;
    final forum = FanForum.fromMap(Map<String, dynamic>.from(row));
    final membership = await getMyMembership(forumId);
    return forum.withMembership(membership);
  }

  Future<List<FanForum>> _attachMemberships(List<FanForum> forums) async {
    final profileId = currentProfileId;
    if (profileId == null || forums.isEmpty) return forums;
    final rows = await supabase
        .from('fan_forum_members')
        .select()
        .eq('profile_id', profileId)
        .inFilter('forum_id', forums.map((forum) => forum.id).toList());
    final byForum = <String, FanForumMembership>{};
    for (final row in rows as List) {
      final membership = FanForumMembership.fromMap(
        Map<String, dynamic>.from(row as Map),
      );
      byForum[membership.forumId] = membership;
    }
    return forums
        .map((forum) => forum.withMembership(byForum[forum.id]))
        .toList();
  }

  Future<FanForumMembership?> getMyMembership(String forumId) async {
    final profileId = currentProfileId;
    if (profileId == null) return null;
    final row = await supabase
        .from('fan_forum_members')
        .select()
        .eq('forum_id', forumId)
        .eq('profile_id', profileId)
        .maybeSingle();
    return row == null
        ? null
        : FanForumMembership.fromMap(Map<String, dynamic>.from(row));
  }

  Future<FanForum> createForum({
    required String name,
    required String description,
    required String guidelines,
    required String joinPolicy,
    required bool isDiscoverable,
    String? linkedWorkId,
    String accentHex = '#C92F35',
  }) async {
    final profileId = currentProfileId;
    if (profileId == null) throw StateError('NOT_AUTHENTICATED');
    final row = await supabase
        .from('fan_forums')
        .insert({
          'owner_id': profileId,
          'linked_work_id': linkedWorkId,
          'name': name.trim(),
          'description': description.trim(),
          'guidelines': guidelines.trim(),
          'join_policy': joinPolicy,
          'is_discoverable': isDiscoverable,
          'accent_hex': accentHex,
        })
        .select(_forumSelect)
        .single();
    final forum = FanForum.fromMap(Map<String, dynamic>.from(row));
    return forum.withMembership(await getMyMembership(forum.id));
  }

  Future<void> updateForum({
    required String forumId,
    required String name,
    required String description,
    required String guidelines,
    required String joinPolicy,
    required bool isDiscoverable,
    String? linkedWorkId,
    required String accentHex,
  }) async {
    await supabase.from('fan_forums').update({
      'name': name.trim(),
      'description': description.trim(),
      'guidelines': guidelines.trim(),
      'join_policy': joinPolicy,
      'is_discoverable': isDiscoverable,
      'linked_work_id': linkedWorkId,
      'accent_hex': accentHex,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', forumId);
  }

  Future<void> requestAccess(String forumId) async {
    final profileId = currentProfileId;
    if (profileId == null) throw StateError('NOT_AUTHENTICATED');
    final existing = await getMyMembership(forumId);
    if (existing?.status == 'rejected') {
      await supabase
          .from('fan_forum_members')
          .update({
            'status': 'pending',
            'requested_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('forum_id', forumId)
          .eq('profile_id', profileId);
      return;
    }
    await supabase.from('fan_forum_members').insert({
      'forum_id': forumId,
      'profile_id': profileId,
      'role': 'member',
      'status': 'pending',
    });
  }

  Future<void> acceptInvitation(String forumId) async {
    final profileId = currentProfileId;
    if (profileId == null) throw StateError('NOT_AUTHENTICATED');
    await supabase
        .from('fan_forum_members')
        .update({
          'status': 'active',
          'joined_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('forum_id', forumId)
        .eq('profile_id', profileId)
        .eq('status', 'invited');
  }

  Future<void> leaveForum(String forumId) async {
    final profileId = currentProfileId;
    if (profileId == null) return;
    await supabase
        .from('fan_forum_members')
        .delete()
        .eq('forum_id', forumId)
        .eq('profile_id', profileId);
  }

  Future<List<FanForumMembership>> getMembers(String forumId) async {
    final rows = await supabase
        .from('fan_forum_members')
        .select(_membershipSelect)
        .eq('forum_id', forumId)
        .order('requested_at');
    return (rows as List)
        .map((row) => FanForumMembership.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<void> updateMembership({
    required String forumId,
    required String profileId,
    required String status,
    String role = 'member',
  }) async {
    await supabase
        .from('fan_forum_members')
        .update({
          'status': status,
          'role': role,
          if (status == 'active')
            'joined_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('forum_id', forumId)
        .eq('profile_id', profileId);
  }

  Future<void> inviteByUsername(String forumId, String username) async {
    final inviterId = currentProfileId;
    if (inviterId == null) throw StateError('NOT_AUTHENTICATED');
    final profile = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username.trim().replaceFirst('@', ''))
        .maybeSingle();
    if (profile == null) throw StateError('PROFILE_NOT_FOUND');
    final profileId = profile['id'] as String;
    final existing = await supabase
        .from('fan_forum_members')
        .select('status')
        .eq('forum_id', forumId)
        .eq('profile_id', profileId)
        .maybeSingle();
    if (existing == null) {
      await supabase.from('fan_forum_members').insert({
        'forum_id': forumId,
        'profile_id': profileId,
        'role': 'member',
        'status': 'invited',
        'invited_by': inviterId,
      });
      return;
    }
    await supabase
        .from('fan_forum_members')
        .update({
          'role': 'member',
          'status': 'invited',
          'invited_by': inviterId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('forum_id', forumId)
        .eq('profile_id', profileId);
  }

  Future<List<FanForumThread>> getThreads(String forumId) async {
    final rows = await supabase
        .from('fan_forum_threads')
        .select(_threadSelect)
        .eq('forum_id', forumId)
        .order('is_pinned', ascending: false)
        .order('last_activity_at', ascending: false);
    return (rows as List)
        .map((row) => FanForumThread.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<FanForumThread?> getThread(String threadId) async {
    final row = await supabase
        .from('fan_forum_threads')
        .select(_threadSelect)
        .eq('id', threadId)
        .maybeSingle();
    return row == null
        ? null
        : FanForumThread.fromMap(Map<String, dynamic>.from(row));
  }

  Future<FanForumThread> createThread({
    required String forumId,
    required String title,
    required String body,
  }) async {
    final profileId = currentProfileId;
    if (profileId == null) throw StateError('NOT_AUTHENTICATED');
    final row = await supabase
        .from('fan_forum_threads')
        .insert({
          'forum_id': forumId,
          'author_id': profileId,
          'title': title.trim(),
          'body': body.trim(),
        })
        .select(_threadSelect)
        .single();
    return FanForumThread.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> setThreadState({
    required String threadId,
    bool? pinned,
    bool? locked,
  }) async {
    await supabase.from('fan_forum_threads').update({
      if (pinned != null) 'is_pinned': pinned,
      if (locked != null) 'is_locked': locked,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', threadId);
  }

  Future<List<FanForumReply>> getReplies(String threadId) async {
    final rows = await supabase
        .from('fan_forum_replies')
        .select(_replySelect)
        .eq('thread_id', threadId)
        .order('created_at');
    return (rows as List)
        .map((row) => FanForumReply.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<FanForumReply> createReply({
    required String forumId,
    required String threadId,
    required String body,
  }) async {
    final profileId = currentProfileId;
    if (profileId == null) throw StateError('NOT_AUTHENTICATED');
    final row = await supabase
        .from('fan_forum_replies')
        .insert({
          'forum_id': forumId,
          'thread_id': threadId,
          'author_id': profileId,
          'body': body.trim(),
        })
        .select(_replySelect)
        .single();
    return FanForumReply.fromMap(Map<String, dynamic>.from(row));
  }
}
