import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/rpc_error.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conspiration_provider.dart';
import '../../shared/widgets/glass_card.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, int> _stats = {};
  bool _loadingStats = true;
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;
  List<Map<String, dynamic>> _reports = [];
  bool _loadingReports = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadUsers(), _loadReports()]);
  }

  Future<void> _loadStats() async {
    try {
      final users = await supabase.from('profiles').select('id');
      final works = await supabase.from('works').select('id');
      final reports = await supabase.from('reports').select('id');
      final verifs =
          await supabase.from('artist_verification_requests').select('id');
      if (mounted) {
        setState(() {
          _stats = {
            'usuarios': (users as List).length,
            'obras': (works as List).length,
            'reportes': (reports as List).length,
            'verificaciones': (verifs as List).length,
          };
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final data = await supabase
          .from('profiles')
          .select(
              'id, username, display_name, role, is_banned, is_artist_verified, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadReports() async {
    try {
      final data = await supabase
          .from('reports')
          .select(
              'id, reason, status, created_at, reporter_id, target_id, target_type')
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          _loadingReports = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _toggleBan(String userId, bool currentlyBanned) async {
    try {
      // La suspensión pasa por RPC: valida el rol admin en el servidor y deja
      // rastro en admin_audit_log. El cliente ya no puede escribir is_banned.
      unwrapRpc(await supabase.rpc('admin_set_ban', params: {
        'p_target_user_id': userId,
        'p_banned': !currentlyBanned,
        'p_reason': '',
      }));
      await _loadUsers();
    } on CorvusRpcException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConspirationProvider>();
    final accent = cp.accent;

    return Scaffold(
      backgroundColor: cp.base,
      body: Stack(
        children: [
          // Glow background
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              _buildHeader(context, accent),
              _buildStats(accent),
              _buildTabs(accent),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _UsersTab(
                      users: _users,
                      loading: _loadingUsers,
                      onToggleBan: _toggleBan,
                      accent: accent,
                    ),
                    _ReportsTab(
                      reports: _reports,
                      loading: _loadingReports,
                      accent: accent,
                    ),
                    _SettingsTab(accent: accent),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accent) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/discover'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: accent.withValues(alpha: 0.25), width: 0.8),
              ),
              child: Icon(Icons.arrow_back_rounded, color: accent, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PANEL ADMIN',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              Text(
                'Corvus Aeternum',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.55),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: accent.withValues(alpha: 0.25), width: 0.8),
            ),
            child: Icon(Icons.shield_rounded, color: accent, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Color accent) {
    if (_loadingStats) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(color: accent, strokeWidth: 2),
          ),
        ),
      );
    }
    final entries = _stats.entries.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < entries.length - 1 ? 8 : 0),
              child: SolidGlassCard(
                overrideAccent: accent,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  children: [
                    Text(
                      '${e.value}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.key,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabs(Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.14), width: 0.8),
      ),
      child: TabBar(
        controller: _tab,
        dividerColor: Colors.transparent,
        indicatorColor: accent,
        labelColor: accent,
        unselectedLabelColor: accent.withValues(alpha: 0.45),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Usuarios'),
          Tab(text: 'Reportes'),
          Tab(text: 'Config'),
        ],
      ),
    );
  }
}

// ─── Tab Usuarios ─────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool loading;
  final Future<void> Function(String, bool) onToggleBan;
  final Color accent;

  const _UsersTab({
    required this.users,
    required this.loading,
    required this.onToggleBan,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2));
    }
    if (users.isEmpty) {
      return Center(
        child: Text('Sin usuarios',
            style: TextStyle(color: accent.withValues(alpha: 0.5))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final banned = u['is_banned'] as bool? ?? false;
        final verified = u['is_artist_verified'] as bool? ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SolidGlassCard(
            overrideAccent: banned ? Colors.red : accent,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Center(
                    child: Text(
                      (u['display_name'] as String? ??
                              u['username'] as String? ??
                              '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            u['display_name'] as String? ??
                                u['username'] as String? ??
                                '-',
                            style: TextStyle(
                              color: banned
                                  ? Colors.red.withValues(alpha: 0.7)
                                  : accent.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded,
                                size: 12, color: accent),
                          ],
                        ],
                      ),
                      Text(
                        '@${u['username'] ?? ''} · ${u['role'] ?? ''}',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onToggleBan(u['id'] as String, banned),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (banned ? Colors.green : Colors.red)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (banned ? Colors.green : Colors.red)
                            .withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      banned ? 'Desbanear' : 'Banear',
                      style: TextStyle(
                        color: banned ? Colors.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Tab Reportes ─────────────────────────────────────────────────────────────

class _ReportsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final bool loading;
  final Color accent;

  const _ReportsTab({
    required this.reports,
    required this.loading,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2));
    }
    if (reports.isEmpty) {
      return Center(
        child: Text('Sin reportes pendientes',
            style: TextStyle(color: accent.withValues(alpha: 0.5))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: reports.length,
      itemBuilder: (_, i) {
        final r = reports[i];
        final status = r['status'] as String? ?? 'pending';
        final statusColor = switch (status) {
          'resolved' => Colors.green,
          'dismissed' => Colors.grey,
          _ => Colors.orange,
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SolidGlassCard(
            overrideAccent: accent,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r['reason'] as String? ?? 'Sin razón',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tipo: ${r['target_type'] ?? '-'}',
                  style: TextStyle(
                      color: accent.withValues(alpha: 0.5), fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Tab Config ───────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  final Color accent;
  const _SettingsTab({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SolidGlassCard(
            overrideAccent: accent,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panel de administración',
                        style: TextStyle(
                          color: accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Acceso restringido a administradores',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SolidGlassCard(
            overrideAccent: accent,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesión actual',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.6),
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => Text(
                    auth.profile?.username ?? '-',
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
