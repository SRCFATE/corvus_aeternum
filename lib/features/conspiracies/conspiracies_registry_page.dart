import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/conspiracy_membership.dart';
import '../../models/conspiration.dart';
import '../../providers/conspiration_provider.dart';
import '../../services/conspiracy_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../../shared/widgets/conspiracy_emblem.dart';
import 'conspiracy_rituals.dart';

/// Registro de las Casas — explorar el Libro de las Conspiraciones,
/// elegir primaria manualmente, gestionar secundarias y realizar La Muda.
class ConspiraciesRegistryPage extends StatefulWidget {
  final List<Conspiration>? initialCatalog;
  final EffectiveMemberships? initialMemberships;
  final MoltEligibility? initialMoltEligibility;
  final List<ConspiracyProgress>? initialProgress;

  const ConspiraciesRegistryPage({
    super.key,
    this.initialCatalog,
    this.initialMemberships,
    this.initialMoltEligibility,
    this.initialProgress,
  });

  @override
  State<ConspiraciesRegistryPage> createState() =>
      _ConspiraciesRegistryPageState();
}

class _ConspiraciesRegistryPageState extends State<ConspiraciesRegistryPage> {
  final _service = ConspiracyService();
  final _searchController = TextEditingController();

  List<Conspiration> _catalog = [];
  List<ConspiracyProgress> _progress = [];
  EffectiveMemberships _memberships = const EffectiveMemberships();
  MoltEligibility _moltEligibility = const MoltEligibility(eligible: false);
  bool _isLoading = true;
  bool _isActing = false;
  String _query = '';
  String _rarityFilter = 'all';
  String? _selectedHouseId;

  Conspiration? get _selectedHouse {
    for (final house in _catalog) {
      if (house.id == _selectedHouseId) return house;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCatalog != null) {
      _catalog = widget.initialCatalog!;
      _memberships = widget.initialMemberships ?? const EffectiveMemberships();
      _moltEligibility = widget.initialMoltEligibility ??
          const MoltEligibility(eligible: false);
      _progress = widget.initialProgress ?? const [];
      _selectedHouseId = _memberships.primary?.house.id ??
          (_catalog.isEmpty ? null : _catalog.first.id);
      _isLoading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getCatalog(),
        _service.getEffectiveMemberships(),
        _service.getMoltEligibility(),
        _service.refreshProgress().catchError((_) => <ConspiracyProgress>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as List<Conspiration>;
        _memberships = (results[1] as EffectiveMemberships?) ??
            const EffectiveMemberships();
        _moltEligibility = results[2] as MoltEligibility;
        _progress = results[3] as List<ConspiracyProgress>;
        _selectedHouseId = _memberships.primary?.house.id ??
            (_catalog.isEmpty ? null : _catalog.first.id);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.card,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _applyResult(ConspiracyActionResult result,
      {bool celebrate = false}) async {
    if (!result.ok) {
      _showMessage(ConspiracyService.messageFor(result.reasonCode));
      return;
    }
    if (result.memberships != null) {
      setState(() => _memberships = result.memberships!);
    }
    // Recalcular tema con la nueva primaria.
    final primaryId = result.memberships?.primary?.house.id;
    if (primaryId != null && mounted) {
      await context.read<ConspirationProvider>().loadForUser(primaryId);
    }
    if (celebrate && mounted) {
      await showCrowFlight(context);
    }
    if (mounted) {
      final results = await Future.wait([
        _service.getMoltEligibility(),
        _service.refreshProgress().catchError((_) => <ConspiracyProgress>[]),
      ]);
      if (mounted) {
        setState(() {
          _moltEligibility = results[0] as MoltEligibility;
          _progress = results[1] as List<ConspiracyProgress>;
        });
      }
    }
  }

  ConspiracyProgress? _progressFor(String conspiracyId) {
    for (final entry in _progress) {
      if (entry.conspiracyId == conspiracyId) return entry;
    }
    return null;
  }

  // ─── Acciones ────────────────────────────────────────────────────────────────

  Future<void> _choosePrimary(Conspiration house) async {
    final confirmed = await _confirmRitual(
      title: 'Sellar casa primaria',
      accent: house.accentColor,
      body:
          'La ${house.shortName} definirá tu tema, tu voz y tu lugar en el Firmamento. '
          'Después de este sello, solo La Muda —una vez por temporada— podrá cambiarla.',
      confirmLabel: 'Sellar pertenencia',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    final result = await _service.choosePrimary(house.id);
    if (!mounted) return;
    setState(() => _isActing = false);
    await _applyResult(result, celebrate: true);
    if (result.ok) {
      _showMessage('La ${house.shortName} te reconoce como suyo.');
    }
  }

  Future<void> _toggleSecondary(Conspiration house) async {
    final current = _memberships.secondaries.map((s) => s.house.id).toList();
    final isSecondary = current.contains(house.id);
    final updated = isSecondary
        ? current.where((id) => id != house.id).toList()
        : [...current, house.id];

    setState(() => _isActing = true);
    final result = await _service.setSecondaries(updated);
    if (!mounted) return;
    setState(() => _isActing = false);
    await _applyResult(result);
    if (result.ok) {
      _showMessage(isSecondary
          ? 'La ${house.shortName} se aparta de tu camino.'
          : 'La ${house.shortName} camina ahora a tu lado.');
    }
  }

  Future<void> _performMolt(Conspiration house) async {
    final previous = _memberships.primary;
    if (previous == null) return;

    final targetWasSecondary = _memberships.hasSecondary(house.id);
    final slotsUsed =
        _memberships.secondaries.length - (targetWasSecondary ? 1 : 0);
    final canKeep = slotsUsed < 2;
    var keepPrevious = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Ritual de La Muda',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu pluma de la ${previous.house.shortName} caerá al historial, '
                'y la ${house.shortName} se convertirá en tu casa primaria.\n\n'
                'Solo puedes mudar una vez por temporada. El progreso conquistado nunca se borra.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 13,
                    height: 1.55),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: canKeep
                    ? () => setDialogState(() => keepPrevious = !keepPrevious)
                    : null,
                child: Row(
                  children: [
                    Icon(
                      keepPrevious
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 19,
                      color: canKeep
                          ? (keepPrevious
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.45))
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        canKeep
                            ? 'Conservar la ${previous.house.shortName} como secundaria'
                            : 'Sin espacio para conservarla como secundaria (máximo dos)',
                        style: TextStyle(
                          color: canKeep
                              ? Colors.white.withValues(alpha: 0.70)
                              : Colors.white.withValues(alpha: 0.30),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.55))),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Realizar La Muda',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    final result = await _service.performMolt(
      house.id,
      keepPreviousAsSecondary: keepPrevious,
    );
    if (!mounted) return;
    setState(() => _isActing = false);
    await _applyResult(result, celebrate: true);
    if (result.ok) {
      _showMessage('La Muda se ha cumplido. La ${house.shortName} te recibe.');
    }
  }

  Future<bool?> _confirmRitual({
    required String title,
    required String body,
    required String confirmLabel,
    required Color accent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        content: Text(body,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 13,
                height: 1.55)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Aún no',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel,
                style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CorvusCrowLoader(
                label: 'Abriendo el Libro de las Conspiraciones…')),
      );
    }

    final catalogFree = _catalog
        .where((c) => c.rarity == 'free' && c.code != 'cuervo_negro')
        .toList();
    final catalogUnlockable =
        _catalog.where((c) => c.rarity == 'unlockable').toList();
    final catalogLegendary =
        _catalog.where((c) => c.rarity == 'legendary').toList();
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleCatalog = _catalog.where((house) {
      final matchesRarity = _rarityFilter == 'all' ||
          house.rarity == _rarityFilter ||
          (_rarityFilter == 'free' && house.rarity == 'root');
      final searchable = '${house.shortName} ${house.lore ?? ''} '
              '${house.mechanicGeneral ?? ''} ${house.mechanicPassive ?? ''}'
          .toLowerCase();
      return matchesRarity &&
          (normalizedQuery.isEmpty || searchable.contains(normalizedQuery));
    }).toList();
    final free = visibleCatalog
        .where((c) => c.rarity == 'free' && c.code != 'cuervo_negro')
        .toList();
    final unlockable =
        visibleCatalog.where((c) => c.rarity == 'unlockable').toList();
    final legendary =
        visibleCatalog.where((c) => c.rarity == 'legendary').toList();
    final root = visibleCatalog.where((c) => c.rarity == 'root').toList();
    final selectedHouse = _selectedHouse;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                  children: [
                    _buildHeader(
                      freeCount: catalogFree.length,
                      unlockableCount: catalogUnlockable.length,
                      legendaryCount: catalogLegendary.length,
                    ),
                    const SizedBox(height: 20),
                    // Los ritos pendientes van antes que todo: una invitación
                    // caduca, el catálogo no.
                    CorvusReveal(
                      child: ConspiracyRitualsPanel(onChanged: _load),
                    ),
                    CorvusReveal(child: _buildMembershipPanel()),
                    const SizedBox(height: 32),
                    _buildArchiveToolbar(),
                    const SizedBox(height: 18),
                    if (selectedHouse != null) ...[
                      _buildFeaturedFolio(selectedHouse),
                      const SizedBox(height: 28),
                    ],
                    if (visibleCatalog.isEmpty)
                      _buildNoHousesFound()
                    else ...[
                      if (root.isNotEmpty) ...[
                        _buildSectionLabel('LA RAÍZ', root.length),
                        const SizedBox(height: 14),
                        _buildHouseGrid(root,
                            statusOverride: 'Todos los cuervos nacen aquí'),
                        const SizedBox(height: 30),
                      ],
                      _buildSectionLabel('CASAS LIBRES', free.length),
                      const SizedBox(height: 14),
                      _buildHouseGrid(free),
                      const SizedBox(height: 30),
                      _buildSectionLabel('DESBLOQUEABLES', unlockable.length),
                      const SizedBox(height: 14),
                      _buildHouseGrid(unlockable),
                      const SizedBox(height: 30),
                      _buildSectionLabel('LEGENDARIAS', legendary.length),
                      const SizedBox(height: 14),
                      _buildHouseGrid(legendary),
                    ],
                  ],
                ),
              ),
            ),
            if (_isActing)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(child: CorvusCrowLoader()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveToolbar() {
    final search = Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar una Casa, presencia o mecanica',
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar busqueda',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded, size: 17),
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );

    Widget buildFilters({required bool compact}) {
      final button = SegmentedButton<String>(
        showSelectedIcon: false,
        expandedInsets: compact ? EdgeInsets.zero : null,
        segments: [
          const ButtonSegment(value: 'all', label: Text('Todas')),
          const ButtonSegment(value: 'free', label: Text('Libres')),
          ButtonSegment(
            value: 'unlockable',
            label: Text(compact ? 'Desbloq.' : 'Conquistables'),
          ),
          ButtonSegment(
            value: 'legendary',
            label: Text(compact ? 'Leyenda' : 'Legendarias'),
          ),
        ],
        selected: {_rarityFilter},
        onSelectionChanged: (selection) {
          final filter = selection.first;
          String? firstVisibleId;
          for (final house in _catalog) {
            if (filter == 'all' ||
                house.rarity == filter ||
                (filter == 'free' && house.rarity == 'root')) {
              firstVisibleId = house.id;
              break;
            }
          }
          setState(() {
            _rarityFilter = filter;
            _selectedHouseId = firstVisibleId ?? _selectedHouseId;
          });
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
      if (compact) return SizedBox(width: double.infinity, child: button);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: button,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionLabel('INDICE DEL LIBRO'),
              const SizedBox(height: 12),
              search,
              const SizedBox(height: 10),
              buildFilters(compact: true),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionLabel('INDICE DEL LIBRO'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                buildFilters(compact: false),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedFolio(Conspiration house) {
    final progress = _progressFor(house.id);
    final mechanics = <(String, String)>[
      if (house.mechanicGeneral?.isNotEmpty == true)
        ('Naturaleza', house.mechanicGeneral!),
      if (house.mechanicPassive?.isNotEmpty == true)
        ('Presencia', house.mechanicPassive!),
      if (house.mechanicActive?.isNotEmpty == true)
        ('Mecanica', house.mechanicActive!),
    ];

    return CorvusReveal(
      key: ValueKey('folio-${house.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: house.accentColor.withValues(alpha: 0.22),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: house.accentColor,
                child: const SizedBox(width: 4),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HouseEmblem(house: house, size: 52, glowing: false),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FOLIO ${house.registryNumber ?? '—'} / ${_rarityLabel(house.rarity)}',
                                  style: TextStyle(
                                    color: house.accentColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  house.shortName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: 'Abrir ficha completa',
                            child: IconButton(
                              onPressed: () => _openHouse(house),
                              icon: const Icon(Icons.open_in_full_rounded,
                                  size: 18),
                            ),
                          ),
                        ],
                      ),
                      if (house.lore?.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Text(
                          house.lore!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ],
                      if (mechanics.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: mechanics
                              .map((entry) => _FolioMechanic(
                                    label: entry.$1,
                                    text: entry.$2,
                                    color: house.accentColor,
                                  ))
                              .toList(),
                        ),
                      ],
                      if (progress != null) ...[
                        const SizedBox(height: 14),
                        _ConspiracyProgressPanel(
                          progress: progress,
                          accent: house.accentColor,
                          compact: true,
                        ),
                      ],
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

  Widget _buildNoHousesFound() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: const Column(
        children: [
          Icon(Icons.manage_search_rounded,
              color: AppColors.textMuted, size: 30),
          SizedBox(height: 10),
          Text(
            'Ninguna Casa coincide con este indice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // Grid responsivo: dos columnas en pantallas anchas, una en compactas.
  Widget _buildHouseGrid(List<Conspiration> houses, {String? statusOverride}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 720;
        final cardWidth =
            twoCols ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: houses
              .map((c) => SizedBox(
                    width: cardWidth,
                    child: _HouseCard(
                      house: c,
                      selected: c.id == _selectedHouseId,
                      statusLabel: statusOverride ?? _statusFor(c),
                      onTap: () {
                        setState(() => _selectedHouseId = c.id);
                        _openHouse(c);
                      },
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  String? _statusFor(Conspiration house) {
    if (_memberships.primary?.house.id == house.id) return 'Tu casa primaria';
    if (_memberships.hasSecondary(house.id)) return 'Secundaria';
    if (_memberships.unlocks.any((u) => u.id == house.id)) return 'Conquistada';
    final progress = _progressFor(house.id);
    if (progress != null) {
      if (progress.state == 'candidate') return 'Candidatura detectada';
      if (progress.state == 'eligible') return 'Requisito cumplido';
      if (progress.state == 'awakened') return 'Raíz despierta';
      if (progress.state == 'unlocked') return 'Conquistada';
      if (progress.state == 'tracking') {
        return '${progress.metricText} · ${progress.metricLabel}';
      }
    }
    if (house.rarity == 'unlockable') return 'Se conquista con obra';
    if (house.rarity == 'legendary') return 'Se otorga, no se pide';
    return null;
  }

  Widget _buildHeader({
    required int freeCount,
    required int unlockableCount,
    required int legendaryCount,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIBRO DE LAS CONSPIRACIONES',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Registro de las Casas',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Veintidós casas canalizan la Presencia. Las libres se eligen; las demás se conquistan o se otorgan.',
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
                  _HeaderMetric(value: '$freeCount', label: 'libres'),
                  _HeaderMetric(
                      value: '$unlockableCount', label: 'desbloqueables'),
                  _HeaderMetric(value: '$legendaryCount', label: 'legendarias'),
                  if (_moltEligibility.eligible)
                    const _HeaderMetric(
                        value: '◆', label: 'Muda abierta', accent: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Cuervo ambiental — solo decorativo
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: CrowGlyph(
            size: 46,
            color: AppColors.primary.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipPanel() {
    final primary = _memberships.primary;
    final feathers =
        _memberships.history.where((h) => h.eventType == 'molt').toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('TU PERTENENCIA'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MembershipChip(
                label: _memberships.root?.shortName ?? 'Cuervo Negro',
                sublabel: 'raíz',
                color: Colors.white.withValues(alpha: 0.55),
              ),
              if (primary != null)
                _MembershipChip(
                  label: primary.house.shortName,
                  sublabel: 'primaria',
                  color: primary.house.accentColor,
                  emphasized: true,
                ),
              ..._memberships.secondaries.map((s) => _MembershipChip(
                    label: s.house.shortName,
                    sublabel: 'secundaria',
                    color: s.house.accentColor,
                  )),
              ..._memberships.unlocks.map((u) => _MembershipChip(
                    label: u.shortName,
                    sublabel: 'conquistada',
                    color: u.accentColor,
                  )),
            ],
          ),
          if (primary == null) ...[
            const SizedBox(height: 12),
            Text(
              'El Cuervo Negro aún te cobija. Cuando una casa te llame, séllala aquí — o espera al Primer Vuelo.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 12.5,
                  height: 1.5),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.change_circle_outlined,
                    size: 14, color: Colors.white.withValues(alpha: 0.30)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _moltEligibility.eligible
                        ? 'La Muda está disponible esta temporada.'
                        : ConspiracyService.messageFor(
                            _moltEligibility.reasonCode),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (feathers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionLabel('PLUMAS CAÍDAS'),
            const SizedBox(height: 10),
            ...feathers.take(5).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const FallingFeather(height: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${f.fromName ?? '—'} → ${f.toName ?? '—'}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12),
                        ),
                      ),
                      Text(
                        '${f.createdAt.day}/${f.createdAt.month}/${f.createdAt.year}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, [int? count]) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6)),
      if (count != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ),
      ],
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.0),
            ]),
          ),
        ),
      ),
    ]);
  }

  // ─── Ficha de casa ───────────────────────────────────────────────────────────

  void _openHouse(Conspiration house) {
    final isRoot = house.rarity == 'root';
    final isFree = house.rarity == 'free' && !isRoot;
    final isPrimary = _memberships.primary?.house.id == house.id;
    final isSecondary = _memberships.hasSecondary(house.id);
    final hasPrimary = _memberships.hasPrimary;
    final progress = _progressFor(house.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _HouseEmblem(house: house, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REGISTRO ${house.registryNumber ?? '—'} · ${_rarityLabel(house.rarity)}',
                          style: TextStyle(
                              color: house.accentColor.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          house.shortName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (house.lore?.isNotEmpty == true) ...[
                Text(
                  house.lore!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 14,
                      height: 1.65),
                ),
                const SizedBox(height: 18),
              ],
              if (house.mechanicGeneral?.isNotEmpty == true)
                _MechanicRow(label: 'Naturaleza', text: house.mechanicGeneral!),
              if (house.mechanicPassive?.isNotEmpty == true)
                _MechanicRow(label: 'Presencia', text: house.mechanicPassive!),
              if (house.mechanicActive?.isNotEmpty == true)
                _MechanicRow(label: 'Mecánica', text: house.mechanicActive!),
              if (progress != null) ...[
                const SizedBox(height: 18),
                _ConspiracyProgressPanel(
                  progress: progress,
                  accent: house.accentColor,
                ),
              ],
              const SizedBox(height: 22),

              // Las afiliaciones siguen siendo una elección; el progreso y los
              // desbloqueos se resuelven exclusivamente en el servidor.
              if (isRoot)
                _sheetNote(
                    'La raíz no se elige ni se abandona: todos los cuervos nacen aquí.')
              else if (isPrimary)
                _sheetNote('Esta es tu casa primaria. Define tu tema y tu voz.')
              else if (isFree && !hasPrimary) ...[
                _sheetAction(
                  ctx,
                  label: 'Sellar como casa primaria',
                  accent: house.accentColor,
                  filled: true,
                  onTap: () => _choosePrimary(house),
                ),
              ] else if (isFree && hasPrimary) ...[
                _sheetAction(
                  ctx,
                  label: isSecondary
                      ? 'Quitar de mis secundarias'
                      : 'Añadir como secundaria',
                  accent: house.accentColor,
                  onTap: () => _toggleSecondary(house),
                ),
                const SizedBox(height: 10),
                if (_moltEligibility.eligible)
                  _sheetAction(
                    ctx,
                    label: 'Realizar La Muda hacia esta casa',
                    accent: house.accentColor,
                    filled: true,
                    onTap: () => _performMolt(house),
                  )
                else
                  _sheetNote(ConspiracyService.messageFor(
                      _moltEligibility.reasonCode)),
              ] else if (house.rarity == 'unlockable')
                _sheetNote(
                    'Esta casa se conquista con obra y evidencia; no ocupa tus espacios de afiliación.')
              else if (house.rarity == 'legendary')
                _sheetNote(
                    'Las legendarias no compiten ni se piden. Se otorgan.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetAction(
    BuildContext sheetContext, {
    required String label,
    required Color accent,
    bool filled = false,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onTap();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            )
          : OutlinedButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onTap();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.50)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
    );
  }

  Widget _sheetNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            height: 1.45),
      ),
    );
  }

  static String _rarityLabel(String rarity) => switch (rarity) {
        'root' => 'RAÍZ',
        'unlockable' => 'DESBLOQUEABLE',
        'legendary' => 'LEGENDARIA',
        _ => 'CASA LIBRE',
      };
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _HeaderMetric extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;

  const _HeaderMetric({
    required this.value,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        accent ? AppColors.primary : Colors.white.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.primary.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accent
              ? AppColors.primary.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Adaptador del catálogo al sistema compartido de sigilos.
class _HouseEmblem extends StatelessWidget {
  final Conspiration house;
  final double size;
  final bool glowing;

  const _HouseEmblem({
    required this.house,
    this.size = 46,
    this.glowing = true,
  });

  @override
  Widget build(BuildContext context) {
    return ConspiracyEmblem(
      code: house.code,
      symbol: house.symbol,
      label: house.shortName,
      rarity: house.rarity,
      accent: house.accentColor,
      size: size,
      glowing: glowing,
    );
  }
}

class _HouseCard extends StatefulWidget {
  final Conspiration house;
  final String? statusLabel;
  final bool selected;
  final VoidCallback onTap;

  const _HouseCard({
    required this.house,
    this.statusLabel,
    this.selected = false,
    required this.onTap,
  });

  @override
  State<_HouseCard> createState() => _HouseCardState();
}

class _HouseCardState extends State<_HouseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final house = widget.house;
    final accent = house.accentColor;
    final isLegendary = house.rarity == 'legendary';
    final isUnlockable = house.rarity == 'unlockable';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 118,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
          decoration: BoxDecoration(
            color: accent.withValues(
              alpha: widget.selected ? 0.10 : (_hovered ? 0.07 : 0.035),
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected || _hovered
                  ? accent.withValues(alpha: 0.55)
                  : accent.withValues(alpha: isLegendary ? 0.35 : 0.16),
              width: isLegendary ? 1.3 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HouseEmblem(house: house, size: 48, glowing: _hovered),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (house.registryNumber != null) ...[
                          Text(
                            'Nº ${house.registryNumber}',
                            style: TextStyle(
                                color: accent.withValues(alpha: 0.65),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            house.shortName,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLegendary) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.auto_awesome,
                              size: 12, color: accent.withValues(alpha: 0.75)),
                        ] else if (isUnlockable) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_outline_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.30)),
                        ],
                      ],
                    ),
                    if (house.lore?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(
                          house.lore!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 12,
                              height: 1.45),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (widget.statusLabel != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.80),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.50),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              widget.statusLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: accent.withValues(alpha: 0.85),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _hovered ? 1 : 0.25,
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 13, color: accent.withValues(alpha: 0.70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConspiracyProgressPanel extends StatelessWidget {
  final ConspiracyProgress progress;
  final Color accent;
  final bool compact;

  const _ConspiracyProgressPanel({
    required this.progress,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: compact ? const BoxConstraints(maxWidth: 520) : null,
      padding: EdgeInsets.all(compact ? 11 : 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                progress.effectActive
                    ? Icons.bolt_rounded
                    : Icons.track_changes_rounded,
                color: accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.stateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                progress.metricText,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress.ratio,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.metricLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                progress.effectActive
                    ? Icons.check_circle_rounded
                    : Icons.lock_outline_rounded,
                size: 12,
                color: progress.effectActive
                    ? accent
                    : Colors.white.withValues(alpha: 0.30),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  progress.effectLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: progress.effectActive
                        ? accent
                        : Colors.white.withValues(alpha: 0.34),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolioMechanic extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _FolioMechanic({
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text: text,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.52)),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, height: 1.35),
      ),
    );
  }
}

class _MembershipChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final bool emphasized;

  const _MembershipChip({
    required this.label,
    required this.sublabel,
    required this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: emphasized ? 15 : 13, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: emphasized ? 0.20 : 0.07),
            color.withValues(alpha: emphasized ? 0.06 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: color.withValues(alpha: emphasized ? 0.60 : 0.25),
            width: emphasized ? 1.4 : 1),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700)),
          Text(sublabel,
              style: TextStyle(
                  color: color.withValues(alpha: 0.60),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

class _MechanicRow extends StatelessWidget {
  final String label;
  final String text;

  const _MechanicRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label.toUpperCase(),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8)),
          ),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}
