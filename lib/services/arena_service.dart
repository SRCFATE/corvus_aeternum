import '../core/supabase_config.dart';
import '../models/arena.dart';

class ArenaService {
  static const _challengeSelect =
      '*, profiles!arena_challenges_creator_profile_id_fkey(username, display_name, avatar_url), arena_entries(id)';
  static const _entrySelect =
      '*, profiles!arena_entries_profile_id_fkey(username, display_name, avatar_url), works!arena_entries_work_id_fkey(cover_url), arena_votes(voter_profile_id)';

  Future<List<ArenaChallenge>> getChallenges() async {
    final data = await supabase
        .from('arena_challenges')
        .select(_challengeSelect)
        .neq('status', 'draft')
        .order('ends_at', ascending: true);
    return (data as List)
        .map((item) => ArenaChallenge.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ArenaEntry>> getEntries(
    String challengeId, {
    required String viewerId,
  }) async {
    final data = await supabase
        .from('arena_entries')
        .select(_entrySelect)
        .eq('challenge_id', challengeId)
        .neq('status', 'withdrawn')
        .order('created_at');
    final entries = (data as List)
        .map((item) => ArenaEntry.fromMap(
              Map<String, dynamic>.from(item),
              viewerId: viewerId,
            ))
        .toList();
    entries.sort((a, b) => b.votesCount.compareTo(a.votesCount));
    return entries;
  }

  Future<ArenaChallenge> createChallenge({
    required String profileId,
    required String title,
    required String brief,
    required String format,
    required String discipline,
    required String theme,
    required List<String> rules,
    required String prizeDescription,
    required DateTime endsAt,
    required int maxEntries,
  }) async {
    final data = await supabase
        .from('arena_challenges')
        .insert({
          'creator_profile_id': profileId,
          'title': title.trim(),
          'brief': brief.trim(),
          'format': format,
          'discipline': discipline.trim().isEmpty
              ? 'Multidisciplinario'
              : discipline.trim(),
          'theme': theme.trim(),
          'rules': rules,
          'prize_description': prizeDescription.trim(),
          'status': 'open',
          'visibility': 'public',
          'starts_at': DateTime.now().toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'voting_ends_at':
              endsAt.add(const Duration(days: 2)).toUtc().toIso8601String(),
          'max_entries': format == 'duel' ? 2 : maxEntries,
        })
        .select(_challengeSelect)
        .single();
    return ArenaChallenge.fromMap(data);
  }

  Future<void> submitEntry({
    required String challengeId,
    required String profileId,
    required String workId,
    required String title,
    required String statement,
    String? mediaUrl,
  }) async {
    await supabase.from('arena_entries').insert({
      'challenge_id': challengeId,
      'profile_id': profileId,
      'work_id': workId,
      'title': title.trim(),
      'statement': statement.trim(),
      'media_url': mediaUrl,
    });
  }

  Future<void> castVote({
    required String entryId,
    required String voterProfileId,
  }) async {
    await supabase.from('arena_votes').insert({
      'entry_id': entryId,
      'voter_profile_id': voterProfileId,
      'weight': 1,
    });
  }

  Future<void> removeVote({
    required String entryId,
    required String voterProfileId,
  }) async {
    await supabase
        .from('arena_votes')
        .delete()
        .eq('entry_id', entryId)
        .eq('voter_profile_id', voterProfileId);
  }
}
