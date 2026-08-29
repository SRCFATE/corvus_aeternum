import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../providers/conspiration_provider.dart';
import '../../services/profile_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_empty_state.dart';

const _disciplines = [
  'Todas', 'Pintura', 'Fotografía', 'Ilustración', 'Arte Digital',
  'Escultura', 'Música', 'Literatura', 'Cine', 'Diseño', 'Grabado',
];

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});
  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage>
    with SingleTickerProviderStateMixin {
  final _service = ProfileService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<UserProfile> _artists = [];
  final List<String> _recentSearches = [];

  bool _isLoading = true;
  bool _searchOpen = false;
  String _query = '';
  String _discipline = 'Todas';

  Timer? _debounce;
  late final AnimationController _searchAnim;
  late final Animation<double> _searchWidth;

  @override
  void initState() {
    super.initState();
    _searchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _searchWidth = CurvedAnimation(
      parent: _searchAnim,
      curve: Curves.easeInOutCubic,
    );
    _load();
  }

  @override
  void dispose() {
    _searchAnim.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await _service.getArtists(
      query: _query.isEmpty ? null : _query,
      discipline: _discipline == 'Todas' ? null : _discipline,
    );
    if (mounted) setState(() { _artists = results; _isLoading = false; });
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _submitSearch(String value) {
    final q = value.trim();
    if (q.isNotEmpty && !_recentSearches.contains(q)) {
      setState(() {
        _recentSearches.insert(0, q);
        if (_recentSearches.length > 8) _recentSearches.removeLast();
      });
    }
    _searchFocus.unfocus();
    _load();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    _searchAnim.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchAnim.reverse().then((_) {
      if (mounted) {
        _searchController.clear();
        setState(() { _searchOpen = false; _query = ''; });
        _load();
      }
    });
  }

  void _selectRecent(String q) {
    _searchController.text = q;
    setState(() => _query = q);
    _searchFocus.unfocus();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _Header(
            searchOpen: _searchOpen,
            searchController: _searchController,
            searchFocus: _searchFocus,
            searchAnim: _searchWidth,
            accent: accent,
            onOpenSearch: _openSearch,
            onCloseSearch: _closeSearch,
            onQueryChanged: _onQueryChanged,
            onSubmitSearch: _submitSearch,
          ),
          if (!_searchOpen)
            _DisciplineChips(
              selected: _discipline,
              accent: accent,
              onSelect: (d) { setState(() => _discipline = d); _load(); },
            ),
          Expanded(
            child: Stack(
              children: [
                _ArtistsList(
                  artists: _artists,
                  isLoading: _isLoading,
                  accent: accent,
                  columns: _columns(width),
                  isWide: width >= 720,
                ),
                if (_searchOpen && _query.isEmpty && _recentSearches.isNotEmpty)
                  _RecentSearchesOverlay(
                    recents: _recentSearches,
                    onSelect: _selectRecent,
                    onRemove: (q) => setState(() => _recentSearches.remove(q)),
                    onClearAll: () => setState(() => _recentSearches.clear()),
                  ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  int _columns(double width) {
    if (width >= 1100) return 4;
    if (width >= 760) return 3;
    if (width >= 500) return 2;
    return 1;
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool searchOpen;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final Animation<double> searchAnim;
  final Color accent;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSubmitSearch;

  const _Header({
    required this.searchOpen, required this.searchController,
    required this.searchFocus, required this.searchAnim,
    required this.accent, required this.onOpenSearch,
    required this.onCloseSearch, required this.onQueryChanged,
    required this.onSubmitSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 14),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            AnimatedOpacity(
              opacity: searchOpen ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: searchOpen,
                child: const Text(
                  'Artistas',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
            if (!searchOpen) const Spacer(),
            AnimatedBuilder(
              animation: searchAnim,
              builder: (_, __) => _SearchBar(
                searchOpen: searchOpen,
                controller: searchController,
                focusNode: searchFocus,
                accent: accent,
                onOpen: onOpenSearch,
                onClose: onCloseSearch,
                onChanged: onQueryChanged,
                onSubmitted: onSubmitSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final bool searchOpen;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _SearchBar({
    required this.searchOpen, required this.controller, required this.focusNode,
    required this.accent, required this.onOpen, required this.onClose,
    required this.onChanged, required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    if (!searchOpen) {
      return GestureDetector(
        onTap: onOpen,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
          ),
        ),
      );
    }

    return Expanded(
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Buscar artistas...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32), fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () { controller.clear(); onChanged(''); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
                ),
                child: Icon(Icons.keyboard_return_rounded, size: 17, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DISCIPLINE CHIPS
// ─────────────────────────────────────────────────────────────

class _DisciplineChips extends StatelessWidget {
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelect;

  const _DisciplineChips({required this.selected, required this.accent, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _disciplines.length,
        itemBuilder: (_, i) {
          final d = _disciplines[i];
          final sel = selected == d;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? accent : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: sel ? accent : Colors.white.withValues(alpha: 0.09)),
              ),
              child: Text(
                d,
                style: TextStyle(
                  color: sel ? AppColors.background : Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RECENT SEARCHES
// ─────────────────────────────────────────────────────────────

class _RecentSearchesOverlay extends StatelessWidget {
  final List<String> recents;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  const _RecentSearchesOverlay({
    required this.recents, required this.onSelect,
    required this.onRemove, required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 14, color: Colors.white.withValues(alpha: 0.38)),
                  const SizedBox(width: 7),
                  Text('Búsquedas recientes', style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClearAll,
                    child: Text('Borrar todo', style: TextStyle(color: Colors.white.withValues(alpha: 0.30), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            ...recents.map((q) => _RecentItem(query: q, onSelect: () => onSelect(q), onRemove: () => onRemove(q))),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _RecentItem extends StatefulWidget {
  final String query;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  const _RecentItem({required this.query, required this.onSelect, required this.onRemove});
  @override
  State<_RecentItem> createState() => _RecentItemState();
}

class _RecentItemState extends State<_RecentItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          color: _hovered ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.north_west_rounded, size: 13, color: Colors.white.withValues(alpha: 0.28)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.query, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 14, fontWeight: FontWeight.w500))),
              GestureDetector(
                onTap: widget.onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 15, color: Colors.white.withValues(alpha: 0.25))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ARTISTS LIST
// ─────────────────────────────────────────────────────────────

class _ArtistsList extends StatelessWidget {
  final List<UserProfile> artists;
  final bool isLoading;
  final Color accent;
  final int columns;
  final bool isWide;

  const _ArtistsList({
    required this.artists, required this.isLoading,
    required this.accent, required this.columns, required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2));
    }

    if (artists.isEmpty) {
      return const CorvusEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Ningún artista registrado',
        subtitle: 'Los artistas que publiquen su primera obra\naparecerán en el archivo.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 48),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isWide ? 1.1 : 0.95,
      ),
      itemCount: artists.length,
      itemBuilder: (_, i) => _ArtistCard(artist: artists[i], accent: accent),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ARTIST CARD
// ─────────────────────────────────────────────────────────────

class _ArtistCard extends StatefulWidget {
  final UserProfile artist;
  final Color accent;
  const _ArtistCard({required this.artist, required this.accent});
  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
  final _service = ProfileService();
  bool _hovered = false;
  bool? _following;   // null = cargando
  bool _followBusy = false;

  String? get _myId => supabase.auth.currentUser?.id;
  bool get _isSelf => _myId == widget.artist.id;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    final uid = _myId;
    if (uid == null || _isSelf) return;
    final f = await _service.isFollowing(uid, widget.artist.id);
    if (mounted) setState(() => _following = f);
  }

  Future<void> _toggleFollow() async {
    final uid = _myId;
    if (uid == null || _followBusy) return;
    setState(() => _followBusy = true);
    try {
      if (_following == true) {
        await _service.unfollow(uid, widget.artist.id);
        if (mounted) setState(() { _following = false; _followBusy = false; });
      } else {
        await _service.follow(uid, widget.artist.id);
        if (mounted) setState(() { _following = true; _followBusy = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    final accent = widget.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          debugPrint('OPEN ARTIST ID: ${a.id}');
          debugPrint('OPEN ARTIST USERNAME: ${a.username}');
          context.push('/artist/${a.id}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? accent.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.07),
            ),
            boxShadow: _hovered ? [BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 12))] : [],
          ),
          child: Stack(
            children: [
              // Banner
              Positioned(
                top: 0, left: 0, right: 0, height: 72,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: a.bannerUrl != null
                      ? CachedNetworkImage(
                          imageUrl: a.bannerUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _bannerFallback(accent),
                          errorWidget: (_, __, ___) => _bannerFallback(accent),
                        )
                      : _bannerFallback(accent),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 42, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + badges row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.card, width: 3),
                          ),
                          child: _Avatar(profile: a, radius: 26),
                        ),
                        const Spacer(),
                        // Verified
                        if (a.isArtistVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: accent.withValues(alpha: 0.28)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.verified_rounded, size: 11, color: accent),
                              const SizedBox(width: 4),
                              Text('Verificado', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Name
                    Text(
                      a.displayName.isNotEmpty ? a.displayName : a.username,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('@${a.username}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Miembro desde ${a.createdAt.year}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    // Disciplines
                    if (a.disciplines.isNotEmpty)
                      Wrap(spacing: 6, runSpacing: 5, children: a.disciplines.take(3).map((d) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.055),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 0.5),
                          ),
                          child: Text(d, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600)),
                        )
                      ).toList()),
                    const Spacer(),
                    // Stats + Follow
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Stat(value: _fmt(a.worksCount), label: 'obras'),
                                Container(width: 1, height: 18, color: Colors.white.withValues(alpha: 0.08)),
                                _Stat(value: _fmt(a.followersCount), label: 'seg.'),
                              ],
                            ),
                          ),
                        ),
                        if (!_isSelf) ...[
                          const SizedBox(width: 8),
                          if (a.followersCount > 0)
                            _FollowButton(
                              following: _following,
                              busy: _followBusy,
                              accent: accent,
                              onTap: _toggleFollow,
                            )
                          else
                            _ViewProfileButton(
                              onTap: () => context.push('/artist/${a.id}'),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerFallback(Color accent) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [accent.withValues(alpha: 0.18), AppColors.surface],
      ),
    ),
  );

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────
// VIEW PROFILE BUTTON
// ─────────────────────────────────────────────────────────────

class _ViewProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            'Ver perfil',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FOLLOW BUTTON
// ─────────────────────────────────────────────────────────────

class _FollowButton extends StatefulWidget {
  final bool? following;
  final bool busy;
  final Color accent;
  final VoidCallback onTap;

  const _FollowButton({required this.following, required this.busy, required this.accent, required this.onTap});
  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isFollowing = widget.following == true;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isFollowing
                ? Colors.white.withValues(alpha: _hovered ? 0.08 : 0.05)
                : widget.accent.withValues(alpha: _hovered ? 0.95 : 1.0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFollowing
                  ? Colors.white.withValues(alpha: 0.14)
                  : widget.accent,
            ),
            boxShadow: (!isFollowing && _hovered) ? [
              BoxShadow(color: widget.accent.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4)),
            ] : [],
          ),
          child: widget.busy
              ? SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: isFollowing ? Colors.white : AppColors.background,
                  ),
                )
              : Text(
                  widget.following == null
                      ? '...'
                      : isFollowing ? 'Siguiendo' : 'Seguir',
                  style: TextStyle(
                    color: isFollowing ? Colors.white.withValues(alpha: 0.7) : AppColors.background,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ATOMS
// ─────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final UserProfile profile;
  final double radius;
  const _Avatar({required this.profile, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: profile.avatarUrl!,
        imageBuilder: (_, p) => CircleAvatar(radius: radius, backgroundImage: p),
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : profile.username[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.overlay,
      child: Text(initial, style: TextStyle(color: AppColors.textPrimary, fontSize: radius * 0.72, fontWeight: FontWeight.w800)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      const SizedBox(height: 1),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9, fontWeight: FontWeight.w500)),
    ]);
  }
}
