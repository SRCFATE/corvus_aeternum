import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  AdminService(this.client);
  final SupabaseClient client;

  Future<bool> isAdmin() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return false;

    final row = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', uid)
        .maybeSingle();

    return row != null && row['role'] == 'admin';
  }
}
