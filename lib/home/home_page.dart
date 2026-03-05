import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_page.dart';
import '../auth/role_select_page.dart';
import '../profile/profile_page.dart';
import '../admin/admin_panel_page.dart';

final supabase = Supabase.instance.client;

enum HomeMode { user, guest }

/// =======================
///  BASE DE DATOS
/// =======================
class Db {
  // Tables
  static const collections = 'collections';
  static const auctions = 'auctions';
  static const artists = 'artists';

  // Collections columns
  static const cId = 'id';
  static const cTitle = 'title';
  static const cPiecesCount = 'pieces_count';
  static const cCuratorName = 'curator_name';
  static const cCoverUrl = 'cover_url';
  static const cCreatedAt = 'created_at';

  // Auctions columns
  static const aId = 'id';
  static const aLotTitle = 'lot_title'; // si tu tabla usa "title", cámbialo
  static const aArtistName = 'artist_name';
  static const aStatus = 'status'; // live/upcoming/ended
  static const aEndsAt = 'ends_at'; // timestamp
  static const aCurrentBid = 'current_bid';
  static const aCoverUrl = 'cover_url';
  static const aCreatedAt = 'created_at';

  // Artists columns
  static const arId = 'id';
  static const arDisplayName = 'display_name';
  static const arTagline = 'tagline';
  static const arFollowersCount = 'followers_count';
  static const arAvatarUrl = 'avatar_url';
}

/// =======================
///  REPO (Consultas Supabase)
/// =======================
class CorvusRepo {
  final SupabaseClient client;
  CorvusRepo(this.client);

  Future<List<Map<String, dynamic>>> getCollections({int limit = 8}) async {
    final res = await client
        .from(Db.collections)
        .select(
      '${Db.cId},${Db.cTitle},${Db.cPiecesCount},${Db.cCuratorName},${Db.cCoverUrl},${Db.cCreatedAt}',
    )
        .order(Db.cCreatedAt, ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAuctions({int limit = 6}) async {
    final res = await client
        .from(Db.auctions)
        .select(
      '${Db.aId},${Db.aLotTitle},${Db.aArtistName},${Db.aStatus},${Db.aEndsAt},${Db.aCurrentBid},${Db.aCoverUrl},${Db.aCreatedAt}',
    )
        .order(Db.aCreatedAt, ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getArtists({int limit = 10}) async {
    final res = await client
        .from(Db.artists)
        .select(
      '${Db.arId},${Db.arDisplayName},${Db.arTagline},${Db.arFollowersCount},${Db.arAvatarUrl}',
    )
        .order(Db.arFollowersCount, ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> featuredAuction() async {
    final row = await client
        .from(Db.auctions)
        .select(
      '${Db.aId},${Db.aLotTitle},${Db.aArtistName},${Db.aStatus},${Db.aEndsAt},${Db.aCurrentBid},${Db.aCoverUrl},${Db.aCreatedAt}',
    )
        .order(Db.aCreatedAt, ascending: false)
        .limit(1)
        .maybeSingle();
    return row;
  }
}

/// =======================
///  HOME PAGE (THEME-AWARE)
///  -> YA NO HAY COLORES HARDCODEADOS
///  -> TODO SALE DE Theme.of(context)
/// =======================
class HomePage extends StatelessWidget {
  final HomeMode mode;
  const HomePage({super.key, this.mode = HomeMode.user});

  bool get isGuest => mode == HomeMode.guest;
  static const maxWidth = 1180.0;

  @override
  Widget build(BuildContext context) {
    final repo = CorvusRepo(supabase);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: TopBar(isGuest: isGuest)),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isGuest) const GuestBanner(),
                      if (isGuest) const SizedBox(height: 14),

                      HeroSection(repo: repo, isGuest: isGuest),
                      const SizedBox(height: 22),

                      const Highlights(),
                      const SizedBox(height: 26),

                      const SectionHeader(
                        title: 'Colecciones destacadas',
                        subtitle: 'Curaduría editorial, piezas que permanecen.',
                        actionLabel: 'Ver todo',
                      ),
                      const SizedBox(height: 12),
                      CollectionsStripLive(repo: repo),
                      const SizedBox(height: 26),

                      const SectionHeader(
                        title: 'Subastas en vivo y próximas',
                        subtitle: 'Ventanas limitadas. Decisiones rápidas.',
                        actionLabel: 'Ir a subastas',
                      ),
                      const SizedBox(height: 12),
                      AuctionsGridLive(repo: repo, isGuest: isGuest),
                      const SizedBox(height: 26),

                      const SectionHeader(
                        title: 'Artistas del mes',
                        subtitle: 'Voces nuevas, técnica impecable.',
                        actionLabel: 'Explorar artistas',
                      ),
                      const SizedBox(height: 12),
                      ArtistsStripLive(repo: repo, isGuest: isGuest),
                      const SizedBox(height: 34),

                      const Footer(),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  GUEST BANNER (THEME-AWARE)
/// =======================
class GuestBanner extends StatelessWidget {
  const GuestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: _t(context).onSurface.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Navegas como invitado. Puedes explorar, pero para seguir, guardar o participar en subastas necesitas iniciar sesión.',
              style: TextStyle(
                color: _t(context).onSurface.withValues(alpha: 0.82),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CorvusButton(
            label: 'Unirse',
            kind: CorvusButtonKind.primary,
            compact: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoleSelectPage()),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  HERO (THEME-AWARE)
/// =======================
class HeroSection extends StatelessWidget {
  final CorvusRepo repo;
  final bool isGuest;
  const HeroSection({super.key, required this.repo, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 980;

    final scheme = _t(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.10),
            scheme.surface.withValues(alpha: 0.20),
          ],
        ),
      ),
      child: isWide
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: HeroCopy(isGuest: isGuest)),
          const SizedBox(width: 14),
          Expanded(flex: 5, child: HeroArtLive(repo: repo, isGuest: isGuest)),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroCopy(isGuest: isGuest),
          const SizedBox(height: 14),
          HeroArtLive(repo: repo, isGuest: isGuest),
        ],
      ),
    );
  }
}

class HeroCopy extends StatelessWidget {
  final bool isGuest;
  const HeroCopy({super.key, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Pill(icon: Icons.visibility_outlined, text: 'Edición 2026 • Archivo Vivo'),
        const SizedBox(height: 12),
        Text(
          'Arte que no caduca.',
          style: TextStyle(
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Curado. Coleccionable. Hecho para permanecer.\nDescubre colecciones, subastas y autores que construyen legado.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.5,
            color: scheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CorvusButton(
              label: 'Explorar obras',
              kind: CorvusButtonKind.primary,
              onTap: () {
                // TODO: navegar a explorar
              },
            ),
            const SizedBox(width: 10),
            if (isGuest)
              CorvusButton(
                label: 'Aplicar como artista',
                kind: CorvusButtonKind.ghost,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectPage()),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            StatChip(title: 'Curaduría', value: 'Selectiva'),
            StatChip(title: 'Subastas', value: 'Limitadas'),
            StatChip(title: 'Colecciones', value: 'Editoriales'),
            StatChip(title: 'Ranking', value: 'Comunidad'),
          ],
        ),
      ],
    );
  }
}

/// =======================
///  HERO ART (REAL DATA + THEME-AWARE)
/// =======================
class HeroArtLive extends StatefulWidget {
  final CorvusRepo repo;
  final bool isGuest;
  const HeroArtLive({super.key, required this.repo, required this.isGuest});

  @override
  State<HeroArtLive> createState() => _HeroArtLiveState();
}

class _HeroArtLiveState extends State<HeroArtLive> {
  Map<String, dynamic>? row;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repo.featuredAuction();
      if (!mounted) return;
      setState(() => row = r);
    } catch (_) {
      if (!mounted) return;
      setState(() => row = null);
    }
  }

  void _requireAuth(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  String _timeLabel(Map<String, dynamic> r) {
    final status = (r[Db.aStatus] ?? '').toString().toLowerCase();
    final endsAtRaw = r[Db.aEndsAt];

    if (status == 'upcoming') return 'Próxima';
    if (endsAtRaw == null) return '—';

    final endsAt = DateTime.tryParse(endsAtRaw.toString());
    if (endsAt == null) return '—';

    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) return 'Terminó';

    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);
    final r = row;

    final coverUrl = r == null ? null : r[Db.aCoverUrl] as String?;
    final title = r == null ? 'Cargando…' : (r[Db.aLotTitle] ?? 'Lote').toString();
    final bid = r == null ? null : r[Db.aCurrentBid];
    final time = r == null ? '—' : _timeLabel(r);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: (coverUrl != null && coverUrl.isNotEmpty)
                ? Image.network(coverUrl, fit: BoxFit.cover)
                : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    scheme.primary.withValues(alpha: 0.10),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: NoisePainter(tint: scheme.onSurface.withValues(alpha: 0.06)))),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pieza destacada', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
                  const SizedBox(height: 6),
                  Text('“$title”', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.86))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Pill(icon: Icons.local_fire_department_outlined, text: 'Subasta en $time', tight: true),
                      const SizedBox(width: 10),
                      const Pill(icon: Icons.verified_outlined, text: 'Verificada', tight: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Row(
                      children: [
                        Icon(Icons.gavel_rounded, size: 18, color: scheme.onSurface),
                        const SizedBox(width: 10),
                        Text(
                          bid == null ? 'Puja actual: —' : 'Puja actual: $bid',
                          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.88)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CorvusButton(
                  label: 'Ver',
                  kind: CorvusButtonKind.primary,
                  compact: true,
                  onTap: () {
                    if (widget.isGuest) return _requireAuth(context);
                    // TODO: abrir detalle con r[Db.aId]
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  HIGHLIGHTS (THEME-AWARE)
/// =======================
class Highlights extends StatelessWidget {
  const Highlights({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    const items = [
      HighlightData(icon: Icons.tune_rounded, title: 'Curaduría editorial', body: 'Selección humana con criterio y narrativa.'),
      HighlightData(icon: Icons.gavel_rounded, title: 'Subastas limitadas', body: 'Ventanas cortas, piezas memorables.'),
      HighlightData(icon: Icons.verified_rounded, title: 'Verificación', body: 'Autenticidad y trazabilidad.'),
      HighlightData(icon: Icons.leaderboard_rounded, title: 'Comunidad', body: 'Rankings, colecciones y seguimiento.'),
    ];

    if (isWide) {
      return Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(child: HighlightCard(data: items[i])),
            if (i != items.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          HighlightCard(data: items[i]),
          if (i != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class HighlightData {
  final IconData icon;
  final String title;
  final String body;
  const HighlightData({required this.icon, required this.title, required this.body});
}

class HighlightCard extends StatelessWidget {
  final HighlightData data;
  const HighlightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: Icon(data.icon, size: 20, color: scheme.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
                const SizedBox(height: 6),
                Text(
                  data.body,
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.74), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  SECTION HEADER (THEME-AWARE)
/// =======================
class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.onSurface)),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72), height: 1.35)),
            ],
          ),
        ),
        if (isWide) ...[
          const SizedBox(width: 12),
          CorvusButton(
            label: actionLabel,
            kind: CorvusButtonKind.ghost,
            compact: true,
            onTap: () {},
          ),
        ],
      ],
    );
  }
}

/// =======================
///  COLLECTIONS (REAL DATA + THEME-AWARE)
/// =======================
class CollectionsStripLive extends StatelessWidget {
  final CorvusRepo repo;
  const CollectionsStripLive({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getCollections(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 170, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) return ErrorBox(text: 'Error cargando colecciones:\n${snap.error}');
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const EmptyBox(text: 'Aún no hay colecciones publicadas.');

        return SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: rows.length,
            separatorBuilder: (_, i) => const SizedBox(width: 12),
            itemBuilder: (_, i) => CollectionCardRow(row: rows[i]),
          ),
        );
      },
    );
  }
}

class CollectionCardRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const CollectionCardRow({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);

    final title = (row[Db.cTitle] ?? 'Colección').toString();
    final pieces = row[Db.cPiecesCount];
    final curator = (row[Db.cCuratorName] ?? 'Curaduría Corvus').toString();
    final coverUrl = row[Db.cCoverUrl] as String?;

    return SizedBox(
      width: 240,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (coverUrl == null || coverUrl.isEmpty)
                    ? Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: 0.10),
                        scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                  child: Icon(Icons.image_outlined, size: 34, color: scheme.onSurface),
                )
                    : Image.network(coverUrl, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
            const SizedBox(height: 6),
            Text(
              '${pieces ?? '—'} piezas • $curator',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72)),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
///  AUCTIONS (REAL DATA + THEME-AWARE)
/// =======================
class AuctionsGridLive extends StatelessWidget {
  final CorvusRepo repo;
  final bool isGuest;
  const AuctionsGridLive({super.key, required this.repo, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 1100 ? 3 : (w >= 720 ? 2 : 1);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getAuctions(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return ErrorBox(text: 'Error cargando subastas:\n${snap.error}');
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const EmptyBox(text: 'Aún no hay subastas disponibles.');

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (_, i) => AuctionCardRow(row: rows[i], isGuest: isGuest),
        );
      },
    );
  }
}

class AuctionCardRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isGuest;
  const AuctionCardRow({super.key, required this.row, required this.isGuest});

  void _requireAuth(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  String _timeLabel() {
    final status = (row[Db.aStatus] ?? '').toString().toLowerCase();
    final endsAtRaw = row[Db.aEndsAt];

    if (status == 'upcoming') return 'Próxima';
    if (endsAtRaw == null) return '—';

    final endsAt = DateTime.tryParse(endsAtRaw.toString());
    if (endsAt == null) return '—';

    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) return 'Terminó';

    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);

    final title = (row[Db.aLotTitle] ?? 'Lote').toString();
    final artist = (row[Db.aArtistName] ?? '—').toString();
    final bid = row[Db.aCurrentBid];
    final coverUrl = row[Db.aCoverUrl] as String?;

    return GlassCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: (coverUrl == null || coverUrl.isEmpty)
                ? Container(
              width: 110,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.10),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  ],
                ),
              ),
              child: Icon(Icons.photo_outlined, color: scheme.onSurface),
            )
                : Image.network(coverUrl, width: 110, height: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
                const SizedBox(height: 6),
                Text(artist, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.74))),
                const Spacer(),
                Row(
                  children: [
                    Pill(icon: Icons.schedule_rounded, text: _timeLabel(), tight: true),
                    const SizedBox(width: 10),
                    Pill(icon: Icons.gavel_rounded, text: bid == null ? '—' : '$bid', tight: true),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CorvusButton(
                      label: 'Ver',
                      kind: CorvusButtonKind.primary,
                      compact: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    CorvusButton(
                      label: 'Seguir',
                      kind: CorvusButtonKind.ghost,
                      compact: true,
                      onTap: () {
                        if (isGuest) return _requireAuth(context);
                        // TODO: follow real
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  ARTISTS (REAL DATA + THEME-AWARE)
/// =======================
class ArtistsStripLive extends StatelessWidget {
  final CorvusRepo repo;
  final bool isGuest;
  const ArtistsStripLive({super.key, required this.repo, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getArtists(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) return ErrorBox(text: 'Error cargando artistas:\n${snap.error}');
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const EmptyBox(text: 'Aún no hay artistas publicados.');

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: rows.length,
            separatorBuilder: (_, i) => const SizedBox(width: 12),
            itemBuilder: (_, i) => ArtistCardRow(row: rows[i], isGuest: isGuest),
          ),
        );
      },
    );
  }
}

class ArtistCardRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isGuest;
  const ArtistCardRow({super.key, required this.row, required this.isGuest});

  void _requireAuth(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);

    final name = (row[Db.arDisplayName] ?? 'Artista').toString();
    final tag = (row[Db.arTagline] ?? '—').toString();
    final followers = row[Db.arFollowersCount] ?? 0;
    final avatarUrl = row[Db.arAvatarUrl] as String?;

    return SizedBox(
      width: 280,
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                image: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Icon(Icons.person_outline_rounded, color: scheme.onSurface)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
                  const SizedBox(height: 6),
                  Text(tag, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72))),
                  const Spacer(),
                  Text(
                    '$followers seguidores',
                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.62), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CorvusButton(
              label: 'Seguir',
              kind: CorvusButtonKind.primary,
              compact: true,
              onTap: () {
                if (isGuest) return _requireAuth(context);
                // TODO: follow real
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
///  FOOTER (THEME-AWARE)
/// =======================
class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Corvus Aeternum', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            'Curaduría de arte digital. Archivo vivo para coleccionistas y autores.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.72), height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              CorvusButton(label: 'Privacidad', kind: CorvusButtonKind.ghost, compact: true, onTap: () {}),
              CorvusButton(label: 'Términos', kind: CorvusButtonKind.ghost, compact: true, onTap: () {}),
              CorvusButton(label: 'Contacto', kind: CorvusButtonKind.ghost, compact: true, onTap: () {}),
              CorvusButton(label: 'Manifiesto', kind: CorvusButtonKind.ghost, compact: true, onTap: () {}),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '© ${DateTime.now().year} Corvus Aeternum',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.50), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  UI building blocks (THEME-AWARE)
/// =======================
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            // ✅ borde dependiente del outline de la conspiración
            border: Border.all(color: cs.outline.withValues(alpha: 0.40)),

            // ✅ “glass” basado en surfaceContainerHighest (evita surfaceVariant)
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          ),
          child: child,
        ),
      ),
    );
  }
}


class Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool tight;
  const Pill({super.key, required this.icon, required this.text, this.tight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: tight ? 10 : 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.40)),

        // ✅ un toque del primary para que se note la conspiración
        color: cs.primary.withValues(alpha: 0.10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.90)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.88),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  final String title;
  final String value;
  const StatChip({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface)),
        ],
      ),
    );
  }
}

enum CorvusButtonKind { primary, ghost }

class CorvusButton extends StatelessWidget {
  final String label;
  final CorvusButtonKind kind;
  final VoidCallback onTap;
  final bool compact;

  const CorvusButton({
    super.key,
    required this.label,
    required this.kind,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPrimary = kind == CorvusButtonKind.primary;

    final bg = isPrimary ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.35);
    final fg = isPrimary ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.95);
    final borderColor = isPrimary ? Colors.transparent : cs.onSurface.withValues(alpha: 0.45);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 10 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color:borderColor),
          color: bg,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: fg,
            fontSize: 13.2,
          ),
        ),
      ),
    );
  }
}

class NoisePainter extends CustomPainter {
  final Color tint;
  NoisePainter({required this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = tint;
    const step = 14.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = (y / step).floor().isEven ? 0 : step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EmptyBox extends StatelessWidget {
  final String text;
  const EmptyBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);
    return GlassCard(child: Text(text, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75))));
  }
}

class ErrorBox extends StatelessWidget {
  final String text;
  const ErrorBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = _t(context);
    return GlassCard(child: Text(text, style: TextStyle(color: scheme.error.withValues(alpha: 0.90))));
  }
}

/// =======================
///  TOP BAR (THEME-AWARE + TU ADMIN TAP)
/// =======================
class TopBar extends StatefulWidget {

  final bool isGuest;
  const TopBar({super.key, required this.isGuest});


  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  int tapCount = 0;
  DateTime? lastTap;

  Future<bool> _isAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final row = await supabase.from('user_roles').select('role').eq('user_id', user.id).maybeSingle();
    return row != null && row['role'] == 'admin';
  }

  Future<void> _handleSecretTap() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    if (lastTap == null || now.difference(lastTap!) > const Duration(seconds: 2)) {
      tapCount = 0;
    }
    lastTap = now;

    tapCount++;

    if (tapCount >= 5) {
      tapCount = 0;

      final ok = await _isAdmin();
      if (!mounted) return;

      if (ok) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acceso restringido.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = supabase.auth.currentUser;
        final isGuest = widget.isGuest || user == null;

        return Container(
          padding: EdgeInsets.fromLTRB(18, 14 + MediaQuery.of(context).padding.top, 18, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.35))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _handleSecretTap,
                child: Row(
                  children: [
                    Text(
                      'Corvus Aeternum',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cs.onSurface),
                    ),
                    if (isGuest) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
                        ),
                        child: Text(
                          'Invitado',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.80),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              if (isGuest) ...[
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                  child: const Text('Iniciar sesión'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleSelectPage())),
                  child: const Text('Unirse'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                  child: const Text('Perfil'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () async => supabase.auth.signOut(), child: const Text('Cerrar sesión')),
              ],
              if (!isWide) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.menu_rounded, color: cs.onSurface),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// =======================
///  Helper: ColorScheme
/// =======================
ColorScheme _t(BuildContext context) => Theme.of(context).colorScheme;
