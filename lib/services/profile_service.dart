import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService(this.client);
  final SupabaseClient client;

  // -------------------------
  // PROFILES
  // -------------------------

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return row;
  }

  Future<void> createProfile({
    required String displayName,
    required String username,
    required String role, // 'collector' | 'crow'
    required String country,
    String? bio,
    String? conspiracyId,
    String? avatarUrl,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('No hay sesión');

    // Normaliza username (guardamos sin @, recomendado)
    final normalized = _normalizeUsername(username);

    // Validación final de disponibilidad (server-side)
    final ok = await isUsernameAvailable(normalized);
    if (!ok) throw Exception('Ese username ya existe.');

    await client.from('profiles').insert({
      'id': user.id,
      'display_name': displayName.trim(),
      'username': normalized,
      'role': role,
      'country': country,
      'bio': (bio ?? '').trim(),
      'conspiracy_id': conspiracyId,
      'avatar_url': avatarUrl,
    });
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? country,
    String? conspiracyId,
    String? avatarUrl,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('No hay sesión');

    final payload = <String, dynamic>{};
    if (displayName != null) payload['display_name'] = displayName.trim();
    if (bio != null) payload['bio'] = bio.trim();
    if (country != null) payload['country'] = country;
    if (conspiracyId != null) payload['conspiracy_id'] = conspiracyId;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

    if (payload.isEmpty) return;

    await client.from('profiles').update(payload).eq('id', user.id);
  }

  // -------------------------
  // USERNAME
  // -------------------------

  String _normalizeUsername(String input) {
    var s = input.trim().toLowerCase();
    if (s.startsWith('@')) s = s.substring(1);
    s = s.replaceAll(' ', '-');
    s = s.replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    return s;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final normalized = _normalizeUsername(username);

    final row = await client
        .from('profiles')
        .select('id')
        .eq('username', normalized)
        .maybeSingle();

    return row == null;
  }

  // -------------------------
  // CONSPIRACIES (antes constellations)
  // -------------------------

  Future<List<Map<String, dynamic>>> listConspiracies() async {
    final res = await client
        .from('conspirations')
        .select('id, code, name, accent_hex, glow_hex, glow_intensity, motion_profile, ui_rounding')
        .order('name', ascending: true);

    return (res as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // Alias para no romper tu profile_page si aún dice listConstellations
  Future<List<Map<String, dynamic>>> listConstellations() => listConspiracies();

  // -------------------------
  // AVATAR UPLOAD (Supabase Storage)
  // -------------------------

  Future<String> uploadAvatar(File file) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('No hay sesión');

    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    return client.storage.from('avatars').getPublicUrl(path);
  }

  // -------------------------
  // VERIFICATION REQUESTS
  // -------------------------

  Future<Map<String, dynamic>?> myVerificationRequest() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final row = await client
        .from('artist_verification_requests')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return row;
  }

  Future<void> submitVerificationRequest({
    String? message,
    List<String>? links,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('No hay sesión');

    await client.from('verification_requests').insert({
      'user_id': user.id,
      'message': (message ?? '').trim(),
      'links': links ?? <String>[],
      'status': 'pending',
    });
  }
}
