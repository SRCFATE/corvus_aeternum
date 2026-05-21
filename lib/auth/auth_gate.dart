import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_page.dart';
import 'login_page.dart';
import 'create_profile_page.dart';
import 'signup_role.dart';

import '../theme/theme_controller.dart';
import '../theme/conspiracy_mapper.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastAppliedConspiracyKey;

  void _postFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  Future<void> _applyConspiracyThemeFromProfile({
    required SupabaseClient client,
    required Map<String, dynamic> profile,
  }) async {
    final conspiracyId = profile['conspiracy_id'] as String?;
    final conspiracyCode = profile['conspiracy_code'] as String?;

    if (conspiracyId == null && conspiracyCode == null) return;

    final key = conspiracyId ?? conspiracyCode!;
    if (_lastAppliedConspiracyKey == key) return;
    _lastAppliedConspiracyKey = key;

    try {
      Map<String, dynamic>? row;

      if (conspiracyId != null) {
        row = await client.from('conspirations').select().eq('id', conspiracyId).maybeSingle();
      } else {
        row = await client.from('conspirations').select().eq('code', conspiracyCode!).maybeSingle();
      }

      if (!mounted) return;
      if (row != null) {
        themeController.setSkin(skinFromRow(row));
      }
    } catch (_) {
      // silencioso: se queda con skin default
    }
  }

  Future<void> _applyDefaultConspiracyForGuest({
    required SupabaseClient client,
  }) async {
    const key = 'guest_default';
    if (_lastAppliedConspiracyKey == key) return;
    _lastAppliedConspiracyKey = key;

    try {
      // 1) Intenta leer app_settings.default_conspiracy_code (recomendado)
      final settings = await client
          .from('app_settings')
          .select('default_conspiracy_code')
          .eq('id', 1)
          .maybeSingle();

      final code = (settings?['default_conspiracy_code'] as String?)?.trim();

      Map<String, dynamic>? row;

      if (code != null && code.isNotEmpty) {
        row = await client.from('conspirations').select().eq('code', code).maybeSingle();
      }

      // 2) Fallback: conspirations.is_default = true
      row ??= await client.from('conspirations').select().eq('is_default', true).maybeSingle();

      if (!mounted) return;
      if (row != null) {
        themeController.setSkin(skinFromRow(row));
      }
    } catch (_) {
      // silencioso: se queda con skin default
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, _) {
        final session = client.auth.currentSession;

        // ✅ WEB: guest por default si no hay sesión (y aplica tema default)
        if (kIsWeb && session == null) {
          _postFrame(() {
            _applyDefaultConspiracyForGuest(client: client);
          });
          return const HomePage(mode: HomeMode.guest);
        }

        // ✅ MÓVIL: login obligatorio si no hay sesión
        if (session == null) {
          _lastAppliedConspiracyKey = null;
          return const LoginPage();
        }

        // ✅ Con sesión (web o móvil): flujo normal
        return FutureBuilder<Map<String, dynamic>?>(
          future: client.from('profiles').select().eq('id', session.user.id).maybeSingle(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (profileSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Error cargando perfil:\n${profileSnap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final profile = profileSnap.data;

            // ✅ No hay perfil -> crear perfil como Cuervo (rol único)
            if (profile == null) {
              return const CreateProfilePage(role: SignupRole.crow);
            }

            // ✅ Aplicar skin de conspiración sin bloquear Home
            _postFrame(() {
              _applyConspiracyThemeFromProfile(client: client, profile: profile);
            });

            return const HomePage(mode: HomeMode.user);
          },
        );
      },
    );
  }
}
