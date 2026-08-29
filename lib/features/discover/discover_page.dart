import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/work.dart';
import '../../services/work_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_empty_state.dart';

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
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _workService = WorkService();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        child: CustomScrollView(
          slivers: [
            _buildEditorialHero(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildDisciplineChips()),
            if (_isFocused &&
                _recentSearches.isNotEmpty &&
                _searchQuery.isEmpty)
              SliverToBoxAdapter(child: _buildRecentSearches()),
            if (!_isFocused) SliverToBoxAdapter(child: _buildTrendingSection()),
            if (!_isFocused && (_isLoading || _works.isNotEmpty))
              SliverToBoxAdapter(child: _buildSectionLabel('ARCHIVO VIVO')),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                ),
              )
            else if (_works.isEmpty)
              SliverFillRemaining(
                child: CorvusEmptyState(
                  icon: Icons.library_books_outlined,
                  title: _searchQuery.isNotEmpty
                      ? 'Sin resultados para "$_searchQuery"'
                      : 'Todavía no hay piezas registradas',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'Intenta con otra disciplina o término de búsqueda.'
                      : 'Las primeras obras publicadas en esta categoría aparecerán aquí.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _DiscoverGridTile(work: _works[index]),
                    childCount: _works.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _crossAxisCount(context),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildEditorialHero() {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DESCUBRIR',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Arte, literatura\ny archivo vivo.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Piezas registradas por la comunidad.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
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
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDiscipline = d);
              _search();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.overlay,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Text(
                d,
                style: TextStyle(
                  color:
                      selected ? AppColors.background : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
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
    final trending = _works.take(5).toList();

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
            ...List.generate(4, (_) => const _TrendingSkeleton())
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

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1180) return 4;
    if (width >= 860) return 3;
    if (width >= 560) return 2;
    return 1;
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

class _DiscoverGridTile extends StatelessWidget {
  final Work work;
  const _DiscoverGridTile({required this.work});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/work/${work.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
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
                  ? CachedNetworkImage(
                      imageUrl: work.displayImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.overlay),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.overlay),
                    )
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
                            work.authorDisplayName ?? work.authorUsername ?? '',
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
                              color: AppColors.primary.withValues(alpha: 0.85),
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
    );
  }
}
