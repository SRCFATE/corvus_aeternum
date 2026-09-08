import '../core/rpc_error.dart';
import '../core/supabase_config.dart';
import '../models/user_profile.dart';
import '../models/artist_ranking.dart';
import '../models/work.dart';

class ProfileService {
  Future<UserProfile?> getProfileById(String id) async {
    final data =
        await supabase.from('profiles').select().eq('id', id).maybeSingle();

    if (data == null) return null;

    return UserProfile.fromMap(data);
  }

  Future<UserProfile?> getProfileByUsername(String username) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('username', username)
        .maybeSingle();

    if (data == null) return null;

    return UserProfile.fromMap(data);
  }

  Future<UserProfile> updateProfile(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await supabase
        .from('profiles')
        .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return UserProfile.fromMap(data);
  }

  Future<void> follow(String followerId, String followingId) async {
    await supabase.from('profile_follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
    await supabase.rpc('increment_profile_stat', params: {
      'profile_id': followerId,
      'field': 'following_count',
    }).catchError((_) => null);
    await supabase.rpc('increment_profile_stat', params: {
      'profile_id': followingId,
      'field': 'followers_count',
    }).catchError((_) => null);
  }

  Future<void> unfollow(String followerId, String followingId) async {
    await supabase
        .from('profile_follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    final data = await supabase
        .from('profile_follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return data != null;
  }

  Future<List<UserProfile>> searchProfiles(String query,
      {int limit = 20}) async {
    final data = await supabase
        .from('profiles')
        .select()
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .limit(limit);
    return (data as List).map((e) => UserProfile.fromMap(e)).toList();
  }

  Future<List<UserProfile>> getArtists({
    String? query,
    String? discipline,
    int limit = 40,
    int offset = 0,
  }) async {
    try {
      var req = supabase.from('profiles').select();

      if (query != null && query.isNotEmpty) {
        req = req.or(
          'username.ilike.%$query%,display_name.ilike.%$query%',
        );
      }

      if (discipline != null && discipline.isNotEmpty) {
        req = req.contains('disciplines', [discipline]);
      }

      final data = await req
          .order('followers_count', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List).map((e) => UserProfile.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clasificación pública del archivo.
  ///
  /// Se recupera una cohorte acotada y la fórmula se ejecuta en Dart para que
  /// la app y sus pruebas compartan exactamente el mismo criterio. Cuando el
  /// archivo supere este tamaño, esta misma salida puede moverse a una vista
  /// `security_invoker` sin cambiar ninguna pantalla.
  Future<List<ArtistRankingEntry>> getArtistRanking({
    String? discipline,
    int limit = 250,
  }) async {
    var request = supabase.from('profiles').select();

    if (discipline != null && discipline.isNotEmpty) {
      request = request.contains('disciplines', [discipline]);
    }

    final data = await request
        .eq('is_banned', false)
        .order('total_likes_received', ascending: false)
        .limit(limit);
    final profiles =
        (data as List).map((entry) => UserProfile.fromMap(entry)).toList();
    return ArtistRankingEntry.rank(profiles);
  }

  Future<List<Work>> getProfileWorks(String profileId,
      {int limit = 30, int offset = 0}) async {
    final data = await supabase
        .from('works')
        .select(
            '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)')
        .eq('profile_id', profileId)
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => Work.fromMap(e)).toList();
  }

  // Returns null if available, or an error message if taken/reserved.
  Future<String?> checkUsernameAvailability(String username) async {
    final data = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    if (data != null) return 'Este @ ya está registrado';
    return null;
  }

  /// Cambia el @ del usuario en sesión. El límite de una vez por año, el
  /// formato y las palabras reservadas se validan en el servidor: la UI ya no
  /// es la que decide.
  Future<UserProfile> changeUsername(String newUsername) async {
    final result = unwrapRpc(
      await supabase.rpc('change_username', params: {
        'p_new_username': newUsername.trim().toLowerCase(),
      }),
    );
    return UserProfile.fromMap(
      Map<String, dynamic>.from(result['profile'] as Map),
    );
  }
}
