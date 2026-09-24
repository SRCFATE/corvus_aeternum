import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'discovery_order.dart';
import '../../core/router/session_page_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/continue_writing_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_breakpoints.dart';
import '../../core/theme/corvus_design.dart';
import '../../models/work.dart';
import '../../services/work_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_cta.dart';
import '../../shared/widgets/work_card.dart';
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

class _DiscoverPageState extends State<DiscoverPage> with SessionPageState {
  late final WorkService _workService;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedDiscipline = 'Todas';
  List<Work> _works = [];
  bool _isLoading = true;
  bool _isFocused = false;
  String _searchQuery = '';
  int _request = 0;
  Timer? _debounce;
  String? _error;
  DateTime? _previousVisit;
  String get _preferencesKey =>
      'corvus.discover.${context.read<AuthProvider?>()?.profile?.id ?? 'visitor'}';
  @override
  String get sessionKey => 'discover.filters';
  @override
  Map<String, dynamic> captureSession() => {
        'query': _searchQuery,
        'discipline': _selectedDiscipline,
        'recent': List<String>.of(_recentSearches)
      };
  @override
  void restoreSession(Map<String, dynamic> value) {
    _searchQuery = value['query'] as String? ?? '';
    _selectedDiscipline = value['discipline'] as String? ?? 'Todas';
    _searchController.text = _searchQuery;
    _recentSearches
      ..clear()
      ..addAll((value['recent'] as List?)?.whereType<String>() ?? []);
    _search();
  }

  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _workService = widget.service ?? WorkService();
    _loadVisit();
    _search();
    _focusNode
        .addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final request = ++_request;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final works = await _workService.getDiscoverWorks(
        discipline: _selectedDiscipline == 'Todas' ? null : _selectedDiscipline,
        query: _searchQuery.isEmpty ? null : _searchQuery,
        limit: 40,
      );
      if (mounted && request == _request) {
        setState(() {
          _works = orderDiscoveryWorks(
              works,
              _searchQuery.isEmpty && _selectedDiscipline == 'Todas'
                  ? context.read<AuthProvider?>()?.profile?.disciplines ?? []
                  : []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo actualizar el archivo. Inténtalo de nuevo.';
        });
      }
    }
  }

  void _onSearch(String query) {
    _request++;
    _debounce?.cancel();
    setState(() => _searchQuery = query);
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _loadVisit() async {
    try {
      final key = _preferencesKey;
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _previousVisit =
          DateTime.tryParse(preferences.getString('$key.visit') ?? ''));
      await preferences.setString(
          '$key.visit', DateTime.now().toUtc().toIso8601String());
    } catch (_) {/* La exploración funciona sin almacenamiento local. */}
  }

  void _rememberSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    });
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
            key: const PageStorageKey('discover.scroll'),
            slivers: [
              _buildEditorialHero(layout),
              if (context.watch<AuthProvider?>()?.profile?.id
                  case final String profileId)
                SliverToBoxAdapter(
                    child: ContinueWritingCard(
                        key: ValueKey(profileId), profileId: profileId)),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildDisciplineChips()),
              if (_isFocused &&
                  _recentSearches.isNotEmpty &&
                  _searchQuery.isEmpty)
                SliverToBoxAdapter(child: _buildRecentSearches()),
              if (!_isFocused && (_isLoading || _works.isNotEmpty))
                SliverToBoxAdapter(child: _buildSectionLabel('ARCHIVO VIVO')),
              if (!_isFocused &&
                  _searchQuery.isEmpty &&
                  _selectedDiscipline == 'Todas' &&
                  (context
                          .watch<AuthProvider?>()
                          ?.profile
                          ?.disciplines
                          .isNotEmpty ??
                      false))
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                            'Priorizamos obras de las disciplinas de tu perfil.',
                            style: CorvusType.muted))),
              if (_error != null)
                SliverToBoxAdapter(
                    child: ListTile(
                        title: Text(_error!),
                        trailing: TextButton(
                            onPressed: _search,
                            child: const Text('Reintentar')))),
              if (_isLoading && _works.isEmpty)
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
                        child: WorkCard(
                          key: ValueKey('discover-work-${work.id}'),
                          work: work,
                          isNew: _previousVisit != null &&
                              work.createdAt.isAfter(_previousVisit!),
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
                    child: Text.rich(
                      TextSpan(
                        text: 'Arte, literatura\n',
                        children: [
                          TextSpan(
                            text: 'y archivo vivo.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                      style: CorvusType.displayLarge.copyWith(
                        fontSize: 46 * layout.displayScale,
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
                        style: CorvusType.body.copyWith(fontSize: 15),
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
      child: AnimatedContainer(
        duration: CorvusMotion.fast,
        curve: CorvusMotion.standard,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(CorvusRadius.pill),
          border: Border.all(
            color: _isFocused
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                : CorvusSurfaces.fill(CorvusSurfaces.borderBase),
            width: 1,
          ),
          boxShadow: _isFocused ? CorvusElevation.low : null,
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 18, right: 12),
              child: Icon(Icons.search_rounded,
                  color: AppColors.textMuted, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Buscar obras por título o descripción…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: _onSearch,
                onSubmitted: (value) {
                  _rememberSearch(value);
                  _focusNode.unfocus();
                },
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
            style: CorvusType.eyebrow(Colors.white, alpha: 0.34),
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

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 30, 0, 16),
      child: CorvusSectionLabel(
        label: label,
        count: _works.isEmpty ? null : _works.length,
      ),
    );
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
                ? AppColors.textPrimary
                : _hovered
                    ? CorvusSurfaces.fill(CorvusSurfaces.fillRaised)
                    : CorvusSurfaces.fill(CorvusSurfaces.fillSubtle),
            borderRadius: BorderRadius.circular(CorvusRadius.pill),
            border: Border.all(
              color: selected
                  ? AppColors.textPrimary
                  : _hovered
                      ? accent.withValues(alpha: 0.40)
                      : CorvusSurfaces.fill(CorvusSurfaces.borderBase),
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: selected
                  ? AppColors.background
                  : _hovered
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────
