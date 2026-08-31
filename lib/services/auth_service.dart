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

  /// Pide el código de recuperación de 8 caracteres.
  ///
  /// No se usa `resetPasswordForEmail`: su correo lleva un enlace al Site URL
  /// (localhost), que en escritorio no lleva a ninguna parte. La Edge Function
  /// genera el código y manda un correo propio.
  ///
  /// La respuesta es la misma exista o no la cuenta, salvo el límite de envíos.
  Future<void> resetPassword(String email) async {
    try {
      final response = await supabase.functions.invoke(
        'send-recovery-code',
        body: {'email': email.trim().toLowerCase()},
      );

      final data = response.data;
      if (data is Map && data['ok'] != true) {
        throw CorvusRpcException(
          data['reason_code'] as String? ?? 'RECOVERY_ISSUE_FAILED',
          Map<String, dynamic>.from(data),
        );
      }
    } on FunctionException catch (e) {
      // invoke() lanza en respuestas 4xx/5xx en vez de devolverlas: el
      // reason_code viaja dentro de `details` y hay que rescatarlo para no
      // mostrar la excepción cruda al artista.
      final details = e.details;
      final code = details is Map ? details['reason_code'] as String? : null;
      throw CorvusRpcException(
        code ?? 'RECOVERY_ISSUE_FAILED',
        details is Map ? Map<String, dynamic>.from(details) : const {},
      );
    }
  }

  /// Canjea el código y fija la contraseña nueva.
  ///
  /// Al terminar cierra las sesiones abiertas en otros dispositivos, así que
  /// el artista vuelve a entrar con la contraseña recién elegida.
  Future<void> redeemRecoveryCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    unwrapRpc(
      await supabase.rpc('redeem_password_recovery_code', params: {
        'p_email': email.trim().toLowerCase(),
        'p_code': normalizeRecoveryCode(code),
        'p_new_password': newPassword,
      }),
    );
  }

  /// Limpia el código escrito: mayúsculas y sin espacios ni guiones, para que
  /// pegarlo desde el correo funcione aunque arrastre formato.
  static String normalizeRecoveryCode(String input) =>
      input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Future<void> deleteAccount() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No hay sesión activa.');
    }

    await supabase.rpc('delete_user');
    await supabase.auth.signOut();
  }
}