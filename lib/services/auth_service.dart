import 'package:flutter/foundation.dart';
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

  /// Envía el correo de recuperación. Supabase no revela si la dirección
  /// existe, así que la respuesta es la misma en todos los casos.
  Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  /// Canjea el código de recuperación por una sesión temporal.
  ///
  /// Acepta el código de seis dígitos del correo o —si la plantilla solo trae
  /// el enlace— el enlace completo pegado: de ahí se extrae el `token_hash`.
  /// Así el flujo funciona en escritorio sin registrar un esquema de URL.
  Future<void> verifyRecoveryCode({
    required String email,
    required String codeOrLink,
  }) async {
    final input = codeOrLink.trim();
    final tokenHash = _extractTokenHash(input);

    if (tokenHash != null) {
      await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        tokenHash: tokenHash,
      );
      return;
    }

    await supabase.auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim().toLowerCase(),
      token: input,
    );
  }

  /// Establece la nueva contraseña sobre la sesión de recuperación abierta.
  Future<void> updatePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Saca el `token_hash` (o `token`) de un enlace de recuperación pegado.
  /// Devuelve null si el texto no es un enlace, para tratarlo como código.
  @visibleForTesting
  static String? extractTokenHash(String input) => _extractTokenHash(input);

  static String? _extractTokenHash(String input) {
    if (!input.contains('://') && !input.contains('token')) return null;
    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    // El token puede venir en la query o tras el # del fragmento.
    final params = <String, String>{
      ...uri.queryParameters,
      if (uri.fragment.isNotEmpty)
        ...Uri.splitQueryString(uri.fragment),
    };
    final hash = params['token_hash'] ?? params['token'];
    return (hash != null && hash.isNotEmpty) ? hash : null;
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