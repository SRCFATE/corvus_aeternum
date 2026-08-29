import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/work.dart';
import '../../providers/conspiration_provider.dart';
import '../../services/work_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/work_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _workService = WorkService();
  final _scrollController = ScrollController();

  final List<Work> _works = [];
  final Set<String> _likedIds = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 420) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final works = await _workService.getFeed(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _works
          ..clear()
          ..addAll(works);
        _hasMore = works.length == _pageSize;
        _isLoading = false;
      });
      await _loadLikedStatus();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _workService.getFeed(
        limit: _pageSize,
        offset: _works.length,
      );
      if (!mounted) return;
      setState(() {
        _works.addAll(more);
        _hasMore = more.length == _pageSize;
        _isLoadingMore = false;
      });
      await _loadLikedStatus();
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadLikedStatus() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    for (final work in _works) {
      if (_likedIds.contains(work.id)) continue;
      final liked = await _workService.isLiked(userId, work.id);
      if (liked && mounted) setState(() => _likedIds.add(work.id));
    }
  }

  Future<void> _toggleLike(String workId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final wasLiked = _likedIds.contains(workId);
    setState(() {
      if (wasLiked) {
        _likedIds.remove(workId);
      } else {
        _likedIds.add(workId);
      }
    });
    try {
      if (wasLiked) {
        await _workService.unlikeWork(userId, workId);
      } else {
        await _workService.likeWork(userId, workId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedIds.add(workId);
        } else {
          _likedIds.remove(workId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: accent,
        backgroundColor: AppColors.surface,
        onRefresh: _loadFeed,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CorvusPage.maxWidth),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroSection(
                    featuredWork: _works.isNotEmpty ? _works.first : null,
                    isLoading: _isLoading,
                    accent: accent,
                    onExplore: () => context.go('/discover'),
                    onFeaturedTap: _works.isNotEmpty
                        ? () => context.push('/work/${_works.first.id}')
                        : null,
                    onFeaturedLike: _works.isNotEmpty
                        ? () => _toggleLike(_works.first.id)
                        : null,
                    featuredLiked: _works.isNotEmpty &&
                        _likedIds.contains(_works.first.id),
                  ),
                ),
                SliverToBoxAdapter(child: _FeatureCards(accent: accent)),
                SliverToBoxAdapter(
                  child: _TrendingHeader(
                    accent: accent,
                    onViewAll: () => context.go('/discover'),
                  ),
                ),
                if (_isLoading)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                else if (_works.length <= 1)
                  SliverToBoxAdapter(child: _EmptyTrending(accent: accent))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final workIndex = index + 1;
                          if (workIndex >= _works.length) {
                            return _LoadingMoreCard(accent: accent);
                          }
                          final work = _works[workIndex];
                          return WorkCard(
                            work: work,
                            isLiked: _likedIds.contains(work.id),
                            onLike: () => _toggleLike(work.id),
                          );
                        },
                        childCount:
                            (_works.length - 1) + (_isLoadingMore ? 1 : 0),
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _crossAxisCount(context),
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1180) return 4;
    if (width >= 900) return 3;
    if (width >= 560) return 2;
    return 1;
  }
}

// ─────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Work? featuredWork;
  final bool isLoading;
  final Color accent;
  final VoidCallback onExplore;
  final VoidCallback? onFeaturedTap;
  final VoidCallback? onFeaturedLike;
  final bool featuredLiked;

  const _HeroSection({
    required this.featuredWork,
    required this.isLoading,
    required this.accent,
    required this.onExplore,
    required this.featuredLiked,
    this.onFeaturedTap,
    this.onFeaturedLike,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 780;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      child: Container(
        height: isWide ? 500 : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.18),
              const Color(0xFF130C12),
              const Color(0xFF0B0A0E),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 42,
              offset: const Offset(0, 22),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SubtleGridPainter(
                    color: Colors.white.withValues(alpha: 0.022),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        accent.withValues(alpha: 0.16),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              if (isWide)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.58),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              isWide ? _wideLayout(context) : _narrowLayout(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 50, child: _textContent(isWide: true)),
          Expanded(
            flex: 50,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 28, 28, 28),
              child: _featuredCard(context),
            ),
          ),
        ],
      );

  Widget _narrowLayout(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _textContent(isWide: false),
          SizedBox(
            height: 300,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: _featuredCard(context),
            ),
          ),
        ],
      );

  Widget _textContent({required bool isWide}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 36 : 24, 24, isWide ? 30 : 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AccentBadge(
                  label: 'Edición 2026 · Archivo Vivo', accent: accent),
              const SizedBox(width: 10),
              if (isWide)
                _SoftBadge(
                  icon: Icons.verified_outlined,
                  label: 'Curaduría activa',
                  accent: accent,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Arte\nque no\ncaduca.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isWide ? 50 : 44,
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Un archivo curado para descubrir, conservar y volver a leer obras que merecen quedarse visibles.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CTAButton(
                  label: 'Explorar obras', accent: accent, onTap: onExplore),
              _SecondaryCTA(
                label: 'Descubrir archivo',
                accent: accent,
                onTap: onExplore,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                label: 'Selectiva',
                caption: 'Curaduría',
                accent: accent,
                icon: Icons.tune_rounded,
              ),
              _Pill(
                label: 'Limitadas',
                caption: 'Subastas',
                accent: accent,
                icon: Icons.gavel_rounded,
              ),
              _Pill(
                label: 'Editoriales',
                caption: 'Colecciones',
                accent: accent,
                icon: Icons.collections_bookmark_outlined,
              ),
              _Pill(
                label: 'Comunidad',
                caption: 'Ranking',
                accent: accent,
                icon: Icons.bar_chart_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featuredCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: featuredWork != null && featuredWork!.hasImage
                  ? CachedNetworkImage(
                      imageUrl: featuredWork!.displayImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.26),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 74,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.54),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccentBadge(
                      label: 'Pieza destacada',
                      accent: accent,
                      icon: Icons.auto_awesome_rounded,
                    ),
                    const Spacer(),
                    if (onFeaturedLike != null)
                      _LikeButton(
                        liked: featuredLiked,
                        onTap: onFeaturedLike!,
                        accent: accent,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 0,
              bottom: 22,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.40),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 22,
              right: 22,
              child: featuredWork == null
                  ? _FeaturedLoadingText(accent: accent)
                  : _FeaturedWorkInfo(
                      work: featuredWork!,
                      accent: accent,
                      onTap: onFeaturedTap,
                    ),
            ),
            if (isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: accent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.card,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.white.withValues(alpha: 0.13),
            size: 56,
          ),
        ),
      );
}

class _FeaturedWorkInfo extends StatelessWidget {
  final Work work;
  final Color accent;
  final VoidCallback? onTap;

  const _FeaturedWorkInfo({
    required this.work,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(
                icon: Icons.visibility_outlined, value: _fmt(work.viewsCount)),
            _StatChip(
                icon: Icons.favorite_border_rounded,
                value: _fmt(work.likesCount)),
            if (work.discipline.isNotEmpty)
              _StatChip(icon: Icons.category_outlined, value: work.discipline),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (work.authorDisplayName != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      work.authorDisplayName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _SmallButton(label: 'Ver', accent: accent, onTap: onTap),
          ],
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _FeaturedLoadingText extends StatelessWidget {
  final Color accent;
  const _FeaturedLoadingText({required this.accent});

  @override
  Widget build(BuildContext context) => Text(
        '"Cargando..."',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// FEATURE CARDS
// ─────────────────────────────────────────────────────────────

class _FeatureCards extends StatelessWidget {
  final Color accent;
  const _FeatureCards({required this.accent});

  static const _cards = [
    (
      Icons.tune_rounded,
      'Curaduría editorial',
      'Selección humana con criterio y narrativa.'
    ),
    (
      Icons.gavel_rounded,
      'Subastas limitadas',
      'Ventanas cortas, piezas memorables.'
    ),
    (
      Icons.verified_rounded,
      'Verificación',
      'Autenticidad y trazabilidad real.'
    ),
    (
      Icons.bar_chart_rounded,
      'Comunidad',
      'Rankings, colecciones y seguimiento.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 900) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Row(
          children: List.generate(_cards.length, (i) {
            final c = _cards[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _cards.length - 1 ? 12 : 0),
                child: _FeatureCard(
                    icon: c.$1, title: c.$2, subtitle: c.$3, accent: accent),
              ),
            );
          }),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 26),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _cards.map((c) {
          return SizedBox(
            width: width >= 560 ? (width - 60) / 2 : double.infinity,
            child: _FeatureCard(
                icon: c.$1, title: c.$2, subtitle: c.$3, accent: accent),
          );
        }).toList(),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hovered
              ? AppColors.cardElevated.withValues(alpha: 0.94)
              : AppColors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hovered
                ? widget.accent.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: hovered
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Icon(widget.icon, color: widget.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.44),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TRENDING
// ─────────────────────────────────────────────────────────────

class _TrendingHeader extends StatelessWidget {
  final Color accent;
  final VoidCallback onViewAll;
  const _TrendingHeader({required this.accent, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                    color: accent.withValues(alpha: 0.45), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trending ahora',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Las obras más queridas por la comunidad.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42), fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          _GhostButton(label: 'Ver todo', onTap: onViewAll),
        ],
      ),
    );
  }
}

class _EmptyTrending extends StatelessWidget {
  final Color accent;
  const _EmptyTrending({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.13), width: 1),
        ),
        child: Text(
          'Sin obras trending todavía.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LoadingMoreCard extends StatelessWidget {
  final Color accent;
  const _LoadingMoreCard({required this.accent});

  @override
  Widget build(BuildContext context) => Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 2),
      );
}

// ─────────────────────────────────────────────────────────────
// ATOMS
// ─────────────────────────────────────────────────────────────

class _AccentBadge extends StatelessWidget {
  final String label;
  final Color accent;
  final IconData? icon;

  const _AccentBadge({required this.label, required this.accent, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 8)
                ],
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _SoftBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent.withValues(alpha: 0.82)),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CTAButton extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _CTAButton(
      {required this.label, required this.accent, required this.onTap});

  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: hovered ? 1.035 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: widget.accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: hovered ? 0.36 : 0.22),
                  blurRadius: hovered ? 24 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.background,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryCTA extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _SecondaryCTA({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_SecondaryCTA> createState() => _SecondaryCTAState();
}

class _SecondaryCTAState extends State<_SecondaryCTA> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: hovered ? 0.075 : 0.045),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered
                  ? widget.accent.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: hovered ? 0.86 : 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String caption;
  final Color accent;
  final IconData icon;

  const _Pill({
    required this.label,
    required this.caption,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent.withValues(alpha: 0.78)),
          const SizedBox(height: 9),
          Text(
            caption,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  const _SmallButton({required this.label, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.background,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final bool liked;
  final VoidCallback onTap;
  final Color accent;

  const _LikeButton(
      {required this.liked, required this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          shape: BoxShape.circle,
          border: Border.all(
            color: liked
                ? accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.13),
            width: 1,
          ),
        ),
        child: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 17,
          color: liked ? accent : Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.58)),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _GhostButton({required this.label, required this.onTap});

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          decoration: BoxDecoration(
            color: hovered
                ? Colors.white.withValues(alpha: 0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: hovered ? 0.16 : 0.09),
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: hovered ? 0.88 : 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUBTLE GRID BACKGROUND
// ─────────────────────────────────────────────────────────────

class _SubtleGridPainter extends CustomPainter {
  final Color color;
  const _SubtleGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 28.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleGridPainter old) => old.color != color;
}
