import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_breakpoints.dart';
import '../../core/theme/corvus_design.dart';
import '../../models/work.dart';
import '../../services/work_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_cta.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../../shared/widgets/corvus_scroll_to_top.dart';
import '../../shared/widgets/corvus_skeleton.dart';

const _filterDisciplines = [
  'Todas',
  'Pintura',
  'Fotografía',
  'Ilustración',
  'Arte Digital',
  'Escultura',
  'Música',
  'Literatura',
  'Cine',
  'Diseño',
  'Grabado',
];

class DiscoverPage extends StatefulWidget {
  final WorkService? service;

  const DiscoverPage({super.key, this.service});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late final WorkService _workService;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedDiscipline = 'Todas';
  List<Work> _works = [];
  bool _isLoading = true;
  bool _isFocused = false;
  String _searchQuery = '';

  final List<String> _recentSearches = [
    'Arte abstracto',
    'Fotografía urbana',
    'Ilustración'
  ];

  @override
  void initState() {
    super.initState();
    _workService = widget.service ?? WorkService();
    _search();
    _focusNode
        .addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    try {
      final works = await _workService.getDiscoverWorks(
        discipline: _selectedDiscipline == 'Todas' ? null : _selectedDiscipline,
        query: _searchQuery.isEmpty ? null : _searchQuery,
        limit: 40,
      );
      if (mounted) {
        setState(() {
          _works = works;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query);
    if (query.length > 2 || query.isEmpty) _search();
  }

  @override
  Widget build(BuildContext context) {
    final layout = CorvusLayout.of(context);
    // En teléfono, una sola portada ocupaba casi toda la altura visible. Dos
    // columnas conservan el carácter editorial de la imagen y permiten
    // comparar piezas sin convertir cada tarjeta en una página completa.
    final compactGrid = layout.isCompact;
    final columns = layout.gridColumns(
      target: compactGrid ? 148 : 260,
      min: compactGrid ? 2 : 1,
      max: 5,
    );
    final cardAspectRatio = compactGrid ? 0.68 : 0.72;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusScrollToTop(
        child: CorvusPage(
          child: CustomScrollView(
            slivers: [
              _buildEditorialHero(layout),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildDisciplineChips()),
              if (_isFocused &&
                  _recentSearches.isNotEmpty &&
                  _searchQuery.isEmpty)
                SliverToBoxAdapter(child: _buildRecentSearches()),
              if (!_isFocused)
                SliverToBoxAdapter(child: _buildTrendingSection()),
              if (!_isFocused && (_isLoading || _works.isNotEmpty))
                SliverToBoxAdapter(child: _buildSectionLabel('ARCHIVO VIVO')),
              if (_isLoading)
                // El aro girando decía "espera" y nada más. El esqueleto dice
                // además qué forma va a tener lo que llega, así que la página
                // no da un salto cuando llega.
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: CorvusSkeletonGrid(
                    crossAxisCount: columns,
                    count: columns * 2,
                    childAspectRatio: cardAspectRatio,
                  ).asSliver(),
                )
              else if (_works.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        CorvusEmptyState(
                          icon: Icons.library_books_outlined,
                          title: _searchQuery.isNotEmpty
                              ? 'Sin resultados para "$_searchQuery"'
                              : 'Todavía no hay piezas registradas',
                          subtitle: _searchQuery.isNotEmpty
                              ? 'Intenta con otra disciplina o término de búsqueda.'
                              : 'Las primeras obras publicadas en esta categoría aparecerán aquí.',
                        ),
                        SizedBox(height: layout.sectionGap),
                        // Una pantalla vacía es el mejor momento para invitar:
                        // no hay nada que interrumpir y sí un hueco que llenar.
                        const CorvusCta(),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final work = _works[index];
                      return CorvusScrollReveal(
                        index: index % columns,
                        child: _DiscoverGridTile(
                          key: ValueKey('discover-work-${work.id}'),
                          work: work,
                        ),
                      );
                    },
                    childCount: _works.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: cardAspectRatio,
                  ),
                ),
                // El cierre del archivo vivo. Quien ha llegado hasta abajo ya
                // ha visto lo que hay: es el momento con más contexto de toda
                // la página para proponer el paso siguiente.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      layout.sectionGap,
                      0,
                      layout.sectionGap,
                    ),
                    child: const CorvusCta(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// El titular de la portada.
  ///
  /// Entra por partes y en orden de lectura —versalita, título, subtítulo,
  /// acción—, con un desfase corto entre ellas. El efecto no es decorativo:
  /// guía la mirada por la jerarquía en el primer segundo, que es justo cuando
  /// alguien decide si esto le interesa. Detrás, un halo del acento de la casa
  /// activa crece una sola vez y se queda.
  Widget _buildEditorialHero(CorvusLayout layout) {
    final accent = Theme.of(context).colorScheme.primary;

    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, layout.isCompact ? 16 : 28, 0, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -120,
                top: -140,
                child: _HeroGlow(accent: accent),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CorvusReveal(
                    beginOffset: const Offset(0, 8),
                    child: Text(
                      'DESCUBRIR',
                      style: CorvusType.eyebrow(accent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CorvusReveal(
                    delay: const Duration(milliseconds: 90),
                    beginOffset: const Offset(0, 16),
                    child: Text(
                      'Arte, literatura\ny archivo vivo.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 40 * layout.displayScale,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        height: 1.06,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CorvusReveal(
                    delay: const Duration(milliseconds: 180),
                    beginOffset: const Offset(0, 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        'Piezas registradas por la comunidad, con fecha y '
                        'autoría. Lo que entra al archivo se queda.',
                        style: CorvusType.body.copyWith(fontSize: 14.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: CorvusSpacing.xl),
                  CorvusReveal(
                    delay: const Duration(milliseconds: 260),
                    beginOffset: const Offset(0, 12),
                    // El primero de los tres momentos en que Corvus invita:
                    // arriba del todo, mientras se decide si quedarse.
                    child: const CorvusCta(tone: CorvusCtaTone.inline),
                  ),
                  SizedBox(height: layout.sectionGap * 0.55),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused ? AppColors.primary : AppColors.border,
            width: _isFocused ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.search_rounded,
                  color: AppColors.textMuted, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Buscar obras, artistas o colecciones...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: _onSearch,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textMuted),
                onPressed: () {
                  _searchController.clear();
                  _onSearch('');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisciplineChips() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _filterDisciplines.length,
        itemBuilder: (_, i) {
          final d = _filterDisciplines[i];
          final selected = _selectedDiscipline == d;
          return _DisciplineChip(
            label: d,
            selected: selected,
            onTap: () {
              setState(() => _selectedDiscipline = d);
              _search();
            },
          );
        },
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BÚSQUEDAS RECIENTES',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ..._recentSearches.map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history,
                    color: AppColors.textMuted, size: 18),
                title: Text(s,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                trailing: GestureDetector(
                  onTap: () => setState(() => _recentSearches.remove(s)),
                  child: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 16),
                ),
                onTap: () {
                  _searchController.text = s;
                  _onSearch(s);
                  _focusNode.unfocus();
                },
              )),
        ],
      ),
    );
  }

  Widget _buildTrendingSection() {
    if (_searchQuery.isNotEmpty) return const SizedBox.shrink();
    final compact = CorvusLayout.of(context).isCompact;
    final trendCount = compact ? 3 : 5;
    final trending = _works.take(trendCount).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              'TENDENCIAS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
                    height: 0.5, color: Colors.white.withValues(alpha: 0.07))),
          ]),
          const SizedBox(height: 16),
          if (_isLoading)
            ...List.generate(trendCount, (_) => const _TrendingSkeleton())
          else if (trending.isEmpty) ...[
            ...List.generate(3, (_) => const _TrendingSkeleton(ghost: true)),
            const SizedBox(height: 14),
            Text(
              'Todavía no hay tendencias registradas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28), fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Las primeras obras publicadas aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.18), fontSize: 12),
            ),
          ] else
            ...trending
                .asMap()
                .entries
                .map((e) => _buildTrendingItem(e.value, e.key)),
        ],
      ),
    );
  }

  Widget _buildTrendingItem(Work work, int index) {
    return GestureDetector(
      onTap: () => context.push('/work/${work.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '0${index + 1}',
                style: TextStyle(
                  color: index == 0 ? AppColors.primary : AppColors.textMuted,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (work.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CachedNetworkImage(
                    imageUrl: work.displayImage,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.overlay),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.overlay),
                  ),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.overlay,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.image_outlined,
                    color: AppColors.textMuted, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    work.discipline.isNotEmpty ? work.discipline : 'Arte',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(height: 2),
                Text(_fmt(work.viewsCount),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Container(
                  height: 0.5, color: Colors.white.withValues(alpha: 0.07))),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// El halo detrás del titular.
///
/// Crece una sola vez al entrar y se queda quieto. Un halo que late convierte
/// la portada en un salvapantallas y compite con el texto que tiene delante;
/// éste solo tiene que dar la sensación de que la página está iluminada desde
/// algún sitio.
class _HeroGlow extends StatelessWidget {
  final Color accent;

  const _HeroGlow({required this.accent});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Opacity(
          opacity: value * 0.5,
          child: Transform.scale(
            scale: 0.8 + 0.2 * value,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.20),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtro de disciplina.
///
/// El estado intermedio importa tanto como los otros dos: sin señal de hover,
/// una fila de once pastillas idénticas no parece pulsable, y en escritorio la
/// gente no prueba a hacer clic en algo que no responde al cursor.
class _DisciplineChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DisciplineChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_DisciplineChip> createState() => _DisciplineChipState();
}

class _DisciplineChipState extends State<_DisciplineChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: CorvusPressable(
        onTap: widget.onTap,
        haptics: true,
        hoverScale: 1.0,
        hoverLift: 0,
        pressedScale: 0.94,
        child: AnimatedContainer(
          duration: CorvusMotion.fast,
          curve: CorvusMotion.standard,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? accent
                : _hovered
                    ? CorvusSurfaces.fill(0.09)
                    : AppColors.overlay,
            borderRadius: BorderRadius.circular(CorvusRadius.pill),
            border: Border.all(
              color: selected
                  ? accent
                  : _hovered
                      ? accent.withValues(alpha: 0.34)
                      : AppColors.border,
              width: 0.5,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: selected ? AppColors.background : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _TrendingSkeleton extends StatelessWidget {
  final bool ghost;
  const _TrendingSkeleton({this.ghost = false});

  @override
  Widget build(BuildContext context) {
    final alpha = ghost ? 0.03 : 0.06;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: ghost ? 0.02 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: ghost ? 0.04 : 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: alpha),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  height: 9,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: alpha * 0.6),
                    borderRadius: BorderRadius.circular(4),
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

// ─── Grid tile ────────────────────────────────────────────────────────────────

class _DiscoverGridTile extends StatefulWidget {
  final Work work;
  const _DiscoverGridTile({super.key, required this.work});

  @override
  State<_DiscoverGridTile> createState() => _DiscoverGridTileState();
}

class _DiscoverGridTileState extends State<_DiscoverGridTile> {
  bool _hovered = false;

  Work get work => widget.work;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: CorvusPressable(
        onTap: () => context.push('/work/${work.id}'),
        hoverScale: 1.022,
        hoverLift: 4,
        pressedScale: 0.985,
        child: AnimatedContainer(
          duration: CorvusMotion.fast,
          curve: CorvusMotion.standard,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CorvusRadius.md),
            color: AppColors.card,
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.07),
            ),
            boxShadow: _hovered
                ? CorvusElevation.glow(accent, strength: 0.9)
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: work.hasImage
                    ? _TileImage(url: work.displayImage, zoomed: _hovered)
                    : Container(
                        color: AppColors.overlay,
                        child: const Center(
                            child: Icon(Icons.image_outlined,
                                color: AppColors.textMuted, size: 32)),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85)
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        work.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              work.authorDisplayName ??
                                  work.authorUsername ??
                                  '',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (work.discipline.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                work.discipline,
                                style: const TextStyle(
                                    color: AppColors.background,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La portada de una tarjeta.
///
/// Dos cosas que no se ven pero se notan. `memCacheWidth` decodifica la imagen
/// al tamaño en que se va a pintar: una foto de 4000 px de ancho metida en una
/// tarjeta de 260 ocupa sesenta veces más memoria de la que necesita, y en un
/// teléfono con veinte tarjetas en pantalla eso es la diferencia entre
/// desplazarse y arrastrarse. Y el fundido de entrada evita el parpadeo del
/// hueco gris cuando la imagen ya venía en caché.
class _TileImage extends StatelessWidget {
  final String url;
  final bool zoomed;

  const _TileImage({required this.url, required this.zoomed});

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return AnimatedScale(
      // Un acercamiento mínimo con el cursor encima: la tarjeta responde sin
      // que la composición se mueva.
      scale: zoomed ? 1.05 : 1,
      duration: CorvusMotion.medium,
      curve: CorvusMotion.standard,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: (420 * ratio).round(),
        fadeInDuration: CorvusMotion.medium,
        placeholder: (_, __) => Container(color: AppColors.overlay),
        errorWidget: (_, __, ___) => Container(color: AppColors.overlay),
      ),
    );
  }
}
