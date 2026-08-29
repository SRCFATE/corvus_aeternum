import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/rpc_error.dart';
import '../core/supabase_config.dart';
import '../models/user_profile.dart';

class AuthService {
  Future<AuthResponse> signIn(String email, String password) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;

    return UserProfile.fromMap(data);
  }

  Future<bool> hasProfile() async {
    final user = currentUser;
    if (user == null) return false;

    final data = await supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    return data != null;
  }

  Future<bool> isUsernameTaken(String username) async {
    final data = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();

    return data != null;
  }

  Future<UserProfile> createProfile({
    String? userId,
    required String username,
    required String displayName,
    required String bio,
    required List<String> disciplines,
    String? country,
  }) async {
    final resolvedId = userId ?? supabase.auth.currentUser?.id;

    if (resolvedId == null) {
      throw Exception(
        'No hay usuario autenticado. Inicia sesión antes de crear el perfil.',
      );
    }

    // El perfil ya existe (lo crea handle_new_user con un @ derivado del
    // correo); esta RPC sella el @ elegido sin gastar la muda anual y es la
    // única vía autorizada para escribir columnas privilegiadas.
    final result = unwrapRpc(
      await supabase.rpc('complete_profile_setup', params: {
        'p_username': username.trim().toLowerCase(),
        'p_display_name': displayName,
        'p_bio': bio,
        'p_disciplines': disciplines,
        'p_country': country,
      }),
    );

    return UserProfile.fromMap(
      Map<String, dynamic>.from(result['profile'] as Map),
    );
  }

  Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> deleteAccount() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No hay sesión activa.');
    }

    await supabase.rpc('delete_user');
    await supabase.auth.signOut();
  }
}