import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  Future<List<Map<String, dynamic>>> _loadPending() async {
    final res = await supabase
        .from('profiles')
        .select('id, username, display_name, country, created_at')
        .eq('profile_type', 'crow')
        .eq('is_artist_verified', false)
        .order('created_at', ascending: false);

    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _verify(String id) async {
    await supabase.from('profiles').update({'is_artist_verified': true}).eq('id', id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadPending(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No hay cuervos pendientes.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                tileColor: Colors.white.withValues(alpha: 0.03),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: Text(p['display_name'] ?? '—'),
                subtitle: Text('@${p['username']} • ${p['country'] ?? '—'}'),
                trailing: FilledButton(
                  onPressed: () => _verify(p['id'] as String),
                  child: const Text('Verificar'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
