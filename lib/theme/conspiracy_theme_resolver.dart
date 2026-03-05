import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme_controller.dart';
import 'conspiracy_mapper.dart';

class ConspiracyThemeResolver {
  ConspiracyThemeResolver(this.client);

  final SupabaseClient client;

  String? _lastKey;

  Future<void> applyForGuest() async {
    const key = 'guest';
    if (_lastKey == key) return;
    _lastKey = key;

    // Opción 1 (recomendada): app_settings.default_conspiracy_code
    final settings = await client
        .from('app_settings')
        .select('default_conspiracy_code')
        .eq('id', 1)
        .maybeSingle();

    final code = settings?['default_conspiracy_code'] as String?;

    Map<String, dynamic>? row;
    if (code != null && code.isNotEmpty) {
      row = await client.from('conspirations').select().eq('code', code).maybeSingle();
    }

    // Opción 2 fallback: conspirations.is_default = true
    row ??= await client.from('conspirations').select().eq('is_default', true).maybeSingle();

    // Si existe row => aplica skin
    if (row != null) {
      themeController.setSkin(skinFromRow(row));
    }
  }

  Future<void> applyForUser(String userId) async {
    final key = 'user:$userId';
    if (_lastKey == key) return;
    _lastKey = key;

    final profile = await client
        .from('profiles')
        .select('conspiracy_id, conspiracy_code')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return;

    final conspiracyId = profile['conspiracy_id'] as String?;
    final conspiracyCode = profile['conspiracy_code'] as String?;

    Map<String, dynamic>? row;

    if (conspiracyId != null) {
      row = await client.from('conspirations').select().eq('id', conspiracyId).maybeSingle();
    } else if (conspiracyCode != null && conspiracyCode.isNotEmpty) {
      row = await client.from('conspirations').select().eq('code', conspiracyCode).maybeSingle();
    }

    if (row != null) {
      themeController.setSkin(skinFromRow(row));
    }
  }

  void resetCache() {
    _lastKey = null;
  }
}
