import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/corvus_motion.dart';
import 'glossary_data.dart';

String _normalize(String value) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const to = 'aaaaaeeeeiiiiooooouuuun';
  var out = value.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key});

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _savedOnly = false;
  final Set<String> _savedTermKeys = {};
  String _selectedCategoryId = expandedGlossaryArtisticCategories.first.id;
  String _selectedSectionId =
      expandedGlossaryArtisticCategories.first.sections.first.id;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GlossaryArtisticCategory> get _categories =>
      expandedGlossaryArtisticCategories;

  GlossaryArtisticCategory get _selectedCategory => _categories.firstWhere(
        (category) => category.id == _selectedCategoryId,
        orElse: () => _categories.first,
      );

  GlossaryCategory _selectedSectionFor(GlossaryArtisticCategory category) {
    return category.sections.firstWhere(
      (section) => section.id == _selectedSectionId,
      orElse: () => category.sections.first,
    );
  }

  void _selectCategory(GlossaryArtisticCategory category) {
    setState(() {
      _selectedCategoryId = category.id;
      _selectedSectionId = category.sections.first.id;
    });
  }

  void _selectSection(GlossaryCategory section) {
    setState(() => _selectedSectionId = section.id);
  }

  List<_GlossarySearchResult> get _searchResults {
    final query = _normalize(_query.trim());
    if (query.isEmpty) return const [];

    final results = <_GlossarySearchResult>[];
    for (final category in _categories) {
      for (final section in category.sections) {
        for (final term in section.terms) {
          if (_termMatches(term, query)) {
            results.add(
              _GlossarySearchResult(
                category: category,
                section: section,
                term: term,
              ),
            );
          }

          for (final child in term.children) {
            if (_termMatches(child, query)) {
              results.add(
                _GlossarySearchResult(
                  category: category,
                  section: section,
                  term: child,
                  parent: term,
                ),
              );
            }
          }
        }
      }
    }
    if (!_savedOnly) return results;
    return results
        .where((result) => _savedTermKeys.contains(
              _termKey(result.category, result.section, result.term),
            ))
        .toList();
  }

  bool _termMatches(GlossaryTerm term, String query) {
    final source = '${term.term} ${term.definition} ${term.example ?? ''}';
    return _normalize(source).contains(query);
  }

  String _termKey(
    GlossaryArtisticCategory category,
    GlossaryCategory section,
    GlossaryTerm term,
  ) =>
      '${category.id}/${section.id}/${_normalize(term.term)}';

  void _toggleSaved(String key) {
    setState(() {
      if (!_savedTermKeys.remove(key)) _savedTermKeys.add(key);
    });
  }

  Future<void> _copyTerm(GlossaryTerm term) async {
    final text = '${term.term}\n${term.definition}'
        '${term.example == null ? '' : '\n${term.example}'}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${term.term} copiado al portapapeles')),
    );
  }

  List<_GlossarySearchResult> get _savedResults {
    final results = <_GlossarySearchResult>[];
    for (final category in _categories) {
      for (final section in category.sections) {
        for (final term in section.terms) {
          if (_savedTermKeys.contains(_termKey(category, section, term))) {
            results.add(_GlossarySearchResult(
              category: category,
              section: section,
              term: term,
            ));
          }
          for (final child in term.children) {
            if (_savedTermKeys.contains(_termKey(category, section, child))) {
              results.add(_GlossarySearchResult(
                category: category,
                section: section,
                term: child,
                parent: term,
              ));
            }
          }
        }
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildQueryTools(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: (_query.trim().isNotEmpty || _savedOnly)
                          ? KeyedSubtree(
                              key: ValueKey('results-$_query-$_savedOnly'),
                              child: _buildSearchResultsList(),
                            )
                          : KeyedSubtree(
                              key: ValueKey('catalog-$isWide'),
                              child: isWide
                                  ? _buildWideLayout()
                                  : _buildCompactLayout(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalSectors = _categories.fold<int>(
        0, (sum, category) => sum + category.sections.length);
    final totalTerms =
        _categories.fold<int>(0, (sum, category) => sum + category.termCount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/feed'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CODICE DEL ARCHIVO',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Glosario',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Categorias artisticas, sectores, generos y subgeneros del archivo creativo.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderMetric(
                    value: '${_categories.length}',
                    label: 'categorias',
                  ),
                  _HeaderMetric(value: '$totalSectors', label: 'sectores'),
                  _HeaderMetric(value: '$totalTerms', label: 'terminos'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 19,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    'Buscar: fantasia oscura, score, webtoon, propiedad...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueryTools() {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: 10),
        Tooltip(
          message:
              _savedOnly ? 'Ver todo el glosario' : 'Ver terminos guardados',
          child: Material(
            color: _savedOnly
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => setState(() => _savedOnly = !_savedOnly),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 46,
                constraints: const BoxConstraints(minWidth: 46),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _savedOnly
                        ? AppColors.primary.withValues(alpha: 0.42)
                        : Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _savedOnly
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color:
                          _savedOnly ? AppColors.primary : AppColors.textMuted,
                      size: 18,
                    ),
                    if (_savedTermKeys.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      Text(
                        '${_savedTermKeys.length}',
                        style: TextStyle(
                          color: _savedOnly
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 286,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: _categories
                .map(
                  (category) => _ArtisticCategoryRailItem(
                    category: category,
                    selected: category.id == _selectedCategoryId,
                    onTap: () => _selectCategory(category),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(child: _buildArtisticCategory(_selectedCategory)),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final category = _categories[index];
              final selected = category.id == _selectedCategoryId;
              return _ArtisticCategoryChip(
                category: category,
                selected: selected,
                onTap: () => _selectCategory(category),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildArtisticCategory(_selectedCategory)),
      ],
    );
  }

  Widget _buildArtisticCategory(GlossaryArtisticCategory category) {
    final selectedSection = _selectedSectionFor(category);

    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        Row(
          children: [
            Icon(
              category.icon,
              size: 19,
              color: AppColors.primary.withValues(alpha: 0.76),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Text(
              '${category.sections.length} sectores · ${category.termCount} terminos',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.30),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          category.subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        _SectorCardGrid(
          category: category,
          selectedSectionId: selectedSection.id,
          onSelected: _selectSection,
        ),
        const SizedBox(height: 18),
        CorvusReveal(
          key: ValueKey('${category.id}/${selectedSection.id}'),
          child: _GlossarySectionBlock(
            category: category,
            section: selectedSection,
            savedTermKeys: _savedTermKeys,
            onToggleSaved: _toggleSaved,
            onCopy: _copyTerm,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    final results = _query.trim().isEmpty ? _savedResults : _searchResults;

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            Text(
              _savedOnly && _query.trim().isEmpty
                  ? 'Aun no has guardado terminos'
                  : 'Sin resultados para "${_query.trim()}"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        Text(
          _savedOnly && _query.trim().isEmpty
              ? '${results.length} terminos guardados'
              : results.length == 1
                  ? '1 resultado'
                  : '${results.length} resultados',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.32),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ...results.map(
          (result) => _TermCard(
            term: result.term,
            termKey: _termKey(
              result.category,
              result.section,
              result.term,
            ),
            categoryLabel: '${result.category.title} / ${result.section.title}',
            categoryIcon: result.category.icon,
            parentLabel: result.parent?.term,
            initiallyExpanded: result.term.children.isNotEmpty,
            isSaved: _savedTermKeys.contains(
              _termKey(result.category, result.section, result.term),
            ),
            onToggleSaved: _toggleSaved,
            onCopy: _copyTerm,
          ),
        ),
      ],
    );
  }
}

class _GlossarySearchResult {
  final GlossaryArtisticCategory category;
  final GlossaryCategory section;
  final GlossaryTerm term;
  final GlossaryTerm? parent;

  const _GlossarySearchResult({
    required this.category,
    required this.section,
    required this.term,
    this.parent,
  });
}

class _HeaderMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderMetric({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtisticCategoryRailItem extends StatefulWidget {
  final GlossaryArtisticCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _ArtisticCategoryRailItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ArtisticCategoryRailItem> createState() =>
      _ArtisticCategoryRailItemState();
}

class _ArtisticCategoryRailItemState extends State<_ArtisticCategoryRailItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primary.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: _hovered ? 0.08 : 0.0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                category.icon,
                size: 17,
                color: widget.selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        color: widget.selected
                            ? AppColors.primary
                            : Colors.white
                                .withValues(alpha: active ? 0.72 : 0.62),
                        fontSize: 13,
                        fontWeight:
                            widget.selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category.sections.length} sectores',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${category.termCount}',
                style: TextStyle(
                  color: widget.selected
                      ? AppColors.primary.withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.24),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtisticCategoryChip extends StatelessWidget {
  final GlossaryArtisticCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _ArtisticCategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.60)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              category.icon,
              size: 14,
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 7),
            Text(
              category.title,
              style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectorCardGrid extends StatelessWidget {
  final GlossaryArtisticCategory category;
  final String selectedSectionId;
  final ValueChanged<GlossaryCategory> onSelected;

  const _SectorCardGrid({
    required this.category,
    required this.selectedSectionId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 3
            : width >= 640
                ? 2
                : 1;
        const gap = 12.0;
        final cardWidth = (width - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: category.sections.map((section) {
            return SizedBox(
              width: cardWidth,
              child: _SectorCard(
                section: section,
                selected: section.id == selectedSectionId,
                onTap: () => onSelected(section),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SectorCard extends StatefulWidget {
  final GlossaryCategory section;
  final bool selected;
  final VoidCallback onTap;

  const _SectorCard({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SectorCard> createState() => _SectorCardState();
}

class _SectorCardState extends State<_SectorCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final active = widget.selected || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: active ? 0.055 : 0.035),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primary.withValues(alpha: 0.46)
                  : Colors.white.withValues(alpha: active ? 0.12 : 0.07),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      section.icon,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ),
                  const Spacer(),
                  _CategoryBadge(
                    label: '${section.termCount}',
                    icon: widget.selected
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                section.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.16,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                section.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlossarySectionBlock extends StatelessWidget {
  final GlossaryArtisticCategory category;
  final GlossaryCategory section;
  final Set<String> savedTermKeys;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<GlossaryTerm> onCopy;

  const _GlossarySectionBlock({
    required this.category,
    required this.section,
    required this.savedTermKeys,
    required this.onToggleSaved,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  section.icon,
                  color: AppColors.primary.withValues(alpha: 0.86),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${section.termCount} terminos',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.30),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            section.subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...section.terms.map((term) {
            final key = '${category.id}/${section.id}/${_normalize(term.term)}';
            return _TermCard(
              term: term,
              termKey: key,
              isSaved: savedTermKeys.contains(key),
              onToggleSaved: onToggleSaved,
              onCopy: onCopy,
            );
          }),
        ],
      ),
    );
  }
}

class _TermCard extends StatefulWidget {
  final GlossaryTerm term;
  final String termKey;
  final String? categoryLabel;
  final IconData? categoryIcon;
  final String? parentLabel;
  final bool initiallyExpanded;
  final bool isSaved;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<GlossaryTerm> onCopy;

  const _TermCard({
    required this.term,
    required this.termKey,
    this.categoryLabel,
    this.categoryIcon,
    this.parentLabel,
    this.initiallyExpanded = false,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onCopy,
  });

  @override
  State<_TermCard> createState() => _TermCardState();
}

class _TermCardState extends State<_TermCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant _TermCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.term != widget.term ||
        oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = widget.term;
    final hasChildren = term.children.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _expanded ? 0.055 : 0.032),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _expanded
              ? AppColors.primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.075),
        ),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasChildren
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      term.term,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              if (hasChildren)
                Tooltip(
                  message: _expanded ? 'Contraer familias' : 'Ver familias',
                  child: IconButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    visualDensity: VisualDensity.compact,
                    icon: AnimatedRotation(
                      duration: const Duration(milliseconds: 160),
                      turns: _expanded ? 0.5 : 0,
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ),
              Tooltip(
                message: 'Copiar definicion',
                child: IconButton(
                  onPressed: () => widget.onCopy(term),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.content_copy_rounded, size: 17),
                ),
              ),
              Tooltip(
                message:
                    widget.isSaved ? 'Quitar de guardados' : 'Guardar termino',
                child: IconButton(
                  onPressed: () => widget.onToggleSaved(widget.termKey),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    widget.isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                    color: widget.isSaved
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (widget.categoryLabel != null) ...[
            const SizedBox(height: 3),
            _CategoryBadge(
              label: widget.categoryLabel!,
              icon: widget.categoryIcon,
            ),
          ],
          if (widget.parentLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              'Dentro de ${widget.parentLabel}',
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            term.definition,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          if (term.example != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.40),
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                term.example!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (hasChildren) ...[
            const SizedBox(height: 12),
            AnimatedCrossFade(
              firstChild: _SubgenrePreview(children: term.children),
              secondChild: Column(
                children: term.children
                    .map((child) => _SubTermRow(term: child))
                    .toList(),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 160),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubgenrePreview extends StatelessWidget {
  final List<GlossaryTerm> children;

  const _SubgenrePreview({required this.children});

  @override
  Widget build(BuildContext context) {
    final visible = children.take(5).toList();
    final remaining = children.length - visible.length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final child in visible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Text(
                child.term,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (remaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                '+$remaining',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.86),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubTermRow extends StatelessWidget {
  final GlossaryTerm term;

  const _SubTermRow({required this.term});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 16,
            color: AppColors.primary.withValues(alpha: 0.58),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  term.term,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  term.definition,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 12,
                    height: 1.42,
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

class _CategoryBadge extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _CategoryBadge({
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: AppColors.primary.withValues(alpha: 0.80),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
