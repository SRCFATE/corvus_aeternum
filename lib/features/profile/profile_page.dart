import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../models/work.dart';
import '../../models/collection.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../services/collection_service.dart';
import '../../services/conspiracy_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_motion.dart';
import '../../shared/widgets/corvus_surface.dart';
import '../../shared/widgets/user_avatar.dart';
import '../../core/theme/corvus_design.dart';
import '../../providers/conspiration_provider.dart';
import '../conspiracies/conspiracy_rituals.dart';
import '../conspiracies/conspiracy_strip.dart';
import '../work/upload_wizard_sheet.dart';

class ProfilePage extends StatefulWidget {
  final String? username;
  final String? userId;

  const ProfilePage({
    super.key,
    this.username,
    this.userId,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _profileService = ProfileService();
  final _collectionService = CollectionService();
  final _conspiracyService = ConspiracyService();
  late TabController _tabController;

  bool get _isExternalProfile =>
      widget.username != null || widget.userId != null;

  UserProfile? _profile;
  List<Work> _works = [];
  List<Collection> _collections = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isOwnProfile = false;
  int _followersAdjustment = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.username != widget.username ||
        oldWidget.userId != widget.userId) {
      _load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _profile = null;
      _works = [];
      _collections = [];
      _followersAdjustment = 0;
      _errorMessage = null;
    });

    final authProfile = context.read<AuthProvider>().profile;

    try {
      UserProfile? profile;

      if (widget.userId != null && widget.userId!.isNotEmpty) {
        profile = await _profileService.getProfileById(widget.userId!);
      } else {
        final targetUsername = widget.username ?? authProfile?.username;

        if (targetUsername == null || targetUsername.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        profile = await _profileService.getProfileByUsername(targetUsername);
      }

      if (profile == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Perfil no encontrado.';
          });
        }
        return;
      }

      _isOwnProfile = authProfile?.id == profile.id;

      final results = await Future.wait([
        _profileService.getProfileWorks(profile.id),
        _collectionService.getUserCollections(profile.id),
        if (!_isOwnProfile && authProfile != null)
          _profileService.isFollowing(authProfile.id, profile.id)
        else
          Future.value(false),
        if (!_isOwnProfile && authProfile != null)
          _conspiracyService
              .recordDirectDiscovery(profile.id)
              .catchError((_) => false)
        else
          Future.value(false),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _works = results[0] as List<Work>;
        _collections = results[1] as List<Collection>;
        _isFollowing = results[2] as bool;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No pudimos cargar este perfil.';
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final authProfile = context.read<AuthProvider>().profile;
    if (authProfile == null || _profile == null) return;
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !_isFollowing;
      _followersAdjustment += _isFollowing ? 1 : -1;
    });
    try {
      if (_isFollowing) {
        await _profileService.follow(authProfile.id, _profile!.id);
      } else {
        await _profileService.unfollow(authProfile.id, _profile!.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followersAdjustment += wasFollowing ? 1 : -1;
        });
      }
    }
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CorvusCrowLoader(label: 'Abriendo perfil...')),
      );
    }

    final authProfile = context.watch<AuthProvider>().profile;
    final profile = _isExternalProfile ? _profile : (_profile ?? authProfile);

    if (profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/feed'),
          ),
        ),
        body: CorvusEmptyState(
          icon: Icons.person_search_outlined,
          title: 'Perfil no encontrado',
          subtitle:
              _errorMessage ?? 'La cuenta no existe o ya no esta disponible.',
          actionText: 'Volver',
          onAction: () =>
              context.canPop() ? context.pop() : context.go('/feed'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                      MediaQuery.sizeOf(context).width < 600 ? 12 : 22,
                      MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: CorvusReveal(child: _buildProfileInfo(profile)),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                      12,
                      MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: ConspiracyStrip(
                        profileId: profile.id,
                        isOwnProfile: _isOwnProfile,
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabsHeaderDelegate(
                      controller: _tabController,
                      worksCount: _works.length,
                      collectionsCount: _collections.length,
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWorksGrid(),
                    _buildCollectionsList(),
                    _buildLegacyView(profile),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(UserProfile profile) {
    return CorvusSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: _ProfileBackdrop(
                profile: profile,
                fallbackImageUrl: _profileBackdropImage,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 820;
                  final content = _ProfileIdentity(
                    profile: profile,
                    isOwnProfile: _isOwnProfile,
                    isFollowing: _isFollowing,
                    worksCount: _works.length,
                    collectionsCount: _collections.length,
                    followersCount: _nonNegative(
                      profile.followersCount + _followersAdjustment,
                    ),
                    onEdit: () async {
                      await context.push('/profile/edit');
                      _load();
                    },
                    onFollow: _toggleFollow,
                    onSignOut: () => context.read<AuthProvider>().signOut(),
                    onBack: _isExternalProfile
                        ? () => context.canPop()
                            ? context.pop()
                            : context.go('/feed')
                        : null,
                    onCopy: _copyToClipboard,
                    statBuilder: _statWidget,
                  );

                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        content,
                        if (_isOwnProfile) ...[
                          const SizedBox(height: 16),
                          _ProfilePromptCard(
                            hasBio: profile.bio.trim().isNotEmpty,
                            hasDisciplines: profile.disciplines.isNotEmpty,
                            hasWorks: _works.isNotEmpty,
                            onEdit: () async {
                              await context.push('/profile/edit');
                              _load();
                            },
                            onPublish: () => showUploadWizard(context),
                          ),
                        ],
                        if (!_isOwnProfile) ...[
                          const SizedBox(height: 16),
                          _RitualInvokeCard(profile: profile),
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: content),
                      if (_isOwnProfile) ...[
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 310,
                          child: _ProfilePromptCard(
                            hasBio: profile.bio.trim().isNotEmpty,
                            hasDisciplines: profile.disciplines.isNotEmpty,
                            hasWorks: _works.isNotEmpty,
                            onEdit: () async {
                              await context.push('/profile/edit');
                              _load();
                            },
                            onPublish: () => showUploadWizard(context),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 310,
                          child: _RitualInvokeCard(profile: profile),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statWidget(int value, String label) {
    return CorvusMetric(value: _format(value), label: label);
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  int _nonNegative(int value) => value < 0 ? 0 : value;

  String? get _profileBackdropImage {
    for (final work in _works) {
      if (work.hasImage) return work.displayImage;
    }
    return null;
  }

  Widget _buildWorksGrid() {
    if (_works.isEmpty) {
      return _ProfileEmptyPanel(
        icon: Icons.auto_awesome_outlined,
        title:
            _isOwnProfile ? 'Tu archivo empieza aqui' : 'Sin obras publicadas',
        subtitle: _isOwnProfile
            ? 'Publica tu primera obra para convertir este perfil en una vitrina viva.'
            : 'Este perfil todavia no tiene obras visibles.',
        actionText: _isOwnProfile ? 'Crear obra' : null,
        onAction: _isOwnProfile ? () => showUploadWizard(context) : null,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisExtent: 340,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _works.length,
      itemBuilder: (context, i) {
        final work = _works[i];
        return CorvusReveal(
          delay: Duration(milliseconds: 45 * (i > 8 ? 8 : i)),
          child: CorvusHoverLift(
            onTap: () => context.push('/work/${work.id}'),
            child: _ProfileWorkCard(work: work),
          ),
        );
      },
    );
  }

  Widget _buildCollectionsList() {
    if (_collections.isEmpty) {
      return _ProfileEmptyPanel(
        icon: Icons.collections_bookmark_outlined,
        title: _isOwnProfile ? 'Crea una sala curatorial' : 'Sin colecciones',
        subtitle: _isOwnProfile
            ? 'Agrupa obras bajo una narrativa: una serie, una exposicion o un archivo personal.'
            : 'Este perfil todavia no tiene colecciones publicas.',
        actionText: _isOwnProfile ? 'Crear coleccion' : null,
        onAction: _isOwnProfile
            ? () async {
                await context.push('/collection/create');
                _load();
              }
            : null,
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 520,
        childAspectRatio: 1.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _collections.length,
      itemBuilder: (context, i) {
        final collection = _collections[i];
        return CorvusReveal(
          delay: Duration(milliseconds: 55 * (i > 7 ? 7 : i)),
          child: CorvusHoverLift(
            onTap: () => context.push('/collection/${collection.id}'),
            child: _ProfileCollectionCard(collection: collection),
          ),
        );
      },
    );
  }

  Widget _buildLegacyView(UserProfile profile) {
    if (_works.isEmpty && _collections.isEmpty) {
      return _ProfileEmptyPanel(
        icon: Icons.history_edu_outlined,
        title: _isOwnProfile ? 'Tu trayectoria comienza aqui' : 'Sin hitos aun',
        subtitle: _isOwnProfile
            ? 'Las obras y colecciones que publiques formaran una memoria viva de tu practica.'
            : 'La trayectoria aparecera cuando este perfil publique obras o colecciones.',
        actionText: _isOwnProfile ? 'Crear obra' : null,
        onAction: _isOwnProfile ? () => showUploadWizard(context) : null,
      );
    }

    final years = _buildLegacyYears(profile);
    final disciplines = <String>{
      ...profile.disciplines.map((value) => value.trim()).where(
            (value) => value.isNotEmpty,
          ),
      ..._works.map((work) => work.discipline.trim()).where(
            (value) => value.isNotEmpty,
          ),
    };
    final earliestYear = years.last.year;
    final currentYear = DateTime.now().year;
    final activeYears =
        currentYear >= earliestYear ? currentYear - earliestYear + 1 : 1;
    final completedWorks = _works.where((work) => work.isComplete).length;
    final featuredWorks = _works.where((work) => work.isFeatured).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 56),
      children: [
        const CorvusSectionHeader(
          eyebrow: 'LEGADO AETERNUM',
          title: 'Trayectoria creativa',
          subtitle:
              'Una cronologia publica construida a partir de obras, series y decisiones curatoriales.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            CorvusMetric(value: '$activeYears', label: 'Anos de trayectoria'),
            CorvusMetric(value: '${_works.length}', label: 'Obras publicadas'),
            CorvusMetric(value: '$completedWorks', label: 'Obras completas'),
            CorvusMetric(value: '${disciplines.length}', label: 'Disciplinas'),
            if (featuredWorks > 0)
              CorvusMetric(value: '$featuredWorks', label: 'Destacadas'),
          ],
        ),
        const SizedBox(height: 30),
        ...years.map(
          (year) => _LegacyYearSection(
            data: year,
            onOpenWork: (work) => context.push('/work/${work.id}'),
            onOpenCollection: (collection) =>
                context.push('/collection/${collection.id}'),
          ),
        ),
      ],
    );
  }

  List<_LegacyYearData> _buildLegacyYears(UserProfile profile) {
    final worksByYear = <int, List<Work>>{};
    final collectionsByYear = <int, List<Collection>>{};

    for (final work in _works) {
      final year = work.year ?? work.createdAt.year;
      worksByYear.putIfAbsent(year, () => []).add(work);
    }
    for (final collection in _collections) {
      collectionsByYear
          .putIfAbsent(collection.createdAt.year, () => [])
          .add(collection);
    }

    final originYear = profile.createdAt.year;
    final years = <int>{
      originYear,
      ...worksByYear.keys,
      ...collectionsByYear.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return years.map((year) {
      final works = worksByYear[year] ?? <Work>[];
      works.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final collections = collectionsByYear[year] ?? <Collection>[];
      collections.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _LegacyYearData(
        year: year,
        works: works,
        collections: collections,
        includesOrigin: year == originYear,
      );
    }).toList();
  }
}

class _ProfileWorkCard extends StatelessWidget {
  final Work work;

  const _ProfileWorkCard({required this.work});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.card,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Icon(
        work.workType == 'text'
            ? Icons.menu_book_outlined
            : Icons.image_outlined,
        color: AppColors.textMuted,
        size: 34,
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: AppColors.overlay,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: work.hasImage
                    ? CachedNetworkImage(
                        imageUrl: work.displayImage,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => fallback,
                        errorWidget: (_, __, ___) => fallback,
                      )
                    : fallback,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (work.discipline.trim().isNotEmpty) ...[
                  Text(
                    work.discipline.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  work.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 13, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text('${work.viewsCount}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite_border_rounded,
                        size: 13, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text('${work.likesCount}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                    const Spacer(),
                    if (work.isFeatured)
                      const Icon(Icons.workspace_premium_outlined,
                          size: 16, color: AppColors.gold),
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

class _ProfileCollectionCard extends StatelessWidget {
  final Collection collection;

  const _ProfileCollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.overlay,
      alignment: Alignment.center,
      child: const Icon(
        Icons.collections_bookmark_outlined,
        color: AppColors.textMuted,
        size: 28,
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 0.92,
            child: collection.coverUrl == null
                ? fallback
                : CachedNetworkImage(
                    imageUrl: collection.coverUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => fallback,
                    errorWidget: (_, __, ___) => fallback,
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    collection.typeLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryLight,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    collection.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_mosaic_outlined,
                          color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        '${collection.piecesCount} obras',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_rounded,
                          color: AppColors.textMuted, size: 17),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyYearData {
  final int year;
  final List<Work> works;
  final List<Collection> collections;
  final bool includesOrigin;

  const _LegacyYearData({
    required this.year,
    required this.works,
    required this.collections,
    required this.includesOrigin,
  });
}

class _LegacyYearSection extends StatelessWidget {
  final _LegacyYearData data;
  final ValueChanged<Work> onOpenWork;
  final ValueChanged<Collection> onOpenCollection;

  const _LegacyYearSection({
    required this.data,
    required this.onOpenWork,
    required this.onOpenCollection,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '${data.year}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 18),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Column(
                children: [
                  ...data.works.map(
                    (work) => _LegacyEntry(
                      icon: work.isFeatured
                          ? Icons.workspace_premium_outlined
                          : Icons.auto_awesome_outlined,
                      iconColor: work.isFeatured
                          ? AppColors.gold
                          : work.isComplete
                              ? AppColors.successLight
                              : AppColors.primary,
                      imageUrl: work.hasImage ? work.displayImage : null,
                      title: work.title,
                      detail: _workDetail(work),
                      onTap: () => onOpenWork(work),
                    ),
                  ),
                  ...data.collections.map(
                    (collection) => _LegacyEntry(
                      icon: Icons.collections_bookmark_outlined,
                      iconColor: collection.isFeatured
                          ? AppColors.gold
                          : AppColors.secondaryLight,
                      imageUrl: collection.coverUrl,
                      title: collection.title,
                      detail:
                          '${collection.typeLabel} / ${collection.piecesCount} obras',
                      onTap: () => onOpenCollection(collection),
                    ),
                  ),
                  if (data.includesOrigin)
                    const _LegacyEntry(
                      icon: Icons.flag_outlined,
                      iconColor: AppColors.textSecondary,
                      title: 'Inicio del archivo publico',
                      detail: 'Ingreso a Corvus Aeternum',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _workDetail(Work work) {
    final details = <String>[
      if (work.discipline.trim().isNotEmpty) work.discipline.trim(),
      if (work.isFeatured) 'Destacada',
      if (work.isComplete) 'Obra completa',
    ];
    return details.isEmpty ? 'Obra publicada' : details.join(' / ');
  }
}

class _LegacyEntry extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? imageUrl;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  const _LegacyEntry({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.055),
              ),
            ),
          ),
          child: Row(
            children: [
              _LegacyThumbnail(
                imageUrl: imageUrl,
                icon: icon,
                iconColor: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacyThumbnail extends StatelessWidget {
  final String? imageUrl;
  final IconData icon;
  final Color iconColor;

  const _LegacyThumbnail({
    required this.imageUrl,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: iconColor.withValues(alpha: 0.11),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 19),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 46,
        height: 46,
        child: imageUrl == null || imageUrl!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _ProfileTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final int worksCount;
  final int collectionsCount;

  const _ProfileTabsHeaderDelegate({
    required this.controller,
    required this.worksCount,
    required this.collectionsCount,
  });

  static const _height = 74.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(
            color: overlapsContent
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
          12,
          MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
          12,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: TabBar(
            controller: controller,
            tabs: [
              Tab(text: 'OBRAS ($worksCount)'),
              Tab(text: 'COLECCIONES ($collectionsCount)'),
              const Tab(text: 'LEGADO'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.worksCount != worksCount ||
        oldDelegate.collectionsCount != collectionsCount;
  }
}

class _ProfileBackdrop extends StatelessWidget {
  final UserProfile profile;
  final String? fallbackImageUrl;

  const _ProfileBackdrop({
    required this.profile,
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.bannerUrl ?? fallbackImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.background.withValues(alpha: 0.90),
                  AppColors.background.withValues(alpha: 0.72),
                  AppColors.background.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.card),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            color: AppColors.primary.withValues(alpha: 0.72),
          ),
        ),
        Positioned(
          right: 38,
          top: -24,
          child: Icon(
            Icons.blur_on_rounded,
            size: 190,
            color: Colors.white.withValues(alpha: 0.025),
          ),
        ),
      ],
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  final UserProfile profile;
  final bool isOwnProfile;
  final bool isFollowing;
  final int worksCount;
  final int collectionsCount;
  final int followersCount;
  final VoidCallback onEdit;
  final VoidCallback onFollow;
  final VoidCallback onSignOut;
  final VoidCallback? onBack;
  final Future<void> Function(String value, String label) onCopy;
  final Widget Function(int value, String label) statBuilder;

  const _ProfileIdentity({
    required this.profile,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.worksCount,
    required this.collectionsCount,
    required this.followersCount,
    required this.onEdit,
    required this.onFollow,
    required this.onSignOut,
    required this.onCopy,
    required this.statBuilder,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile.displayName.isNotEmpty ? profile.displayName : profile.username;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null) ...[
              _ProfileIconAction(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack!,
                tooltip: 'Volver',
              ),
              const SizedBox(width: 12),
            ],
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: UserAvatar(
                imageUrl: profile.avatarUrl,
                displayName: displayName,
                radius: 48,
              ),
            ),
            const Spacer(),
            if (isOwnProfile) ...[
              _ProfileIconAction(
                icon: Icons.edit_outlined,
                onTap: onEdit,
                tooltip: 'Editar perfil',
              ),
              const SizedBox(width: 8),
              _ProfileIconAction(
                icon: Icons.logout_rounded,
                onTap: onSignOut,
                tooltip: 'Cerrar sesion',
              ),
            ] else
              ElevatedButton.icon(
                onPressed: onFollow,
                icon: Icon(
                  isFollowing
                      ? Icons.check_rounded
                      : Icons.person_add_alt_1_rounded,
                  size: 17,
                ),
                label: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          isOwnProfile ? 'TU PORTAFOLIO' : 'PORTAFOLIO PUBLICO',
          style: TextStyle(
            color: AppColors.primary.withValues(alpha: 0.82),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (profile.isArtistVerified) ...[
              const SizedBox(width: 8),
              const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 20),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '@${profile.username}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.46),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          profile.bio.trim().isNotEmpty
              ? profile.bio
              : isOwnProfile
                  ? 'Agrega una bio para contar que tipo de obra estas construyendo.'
                  : 'Este perfil aun no ha escrito una bio.',
          style: TextStyle(
            color: profile.bio.trim().isNotEmpty
                ? AppColors.textSecondary
                : AppColors.textMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (profile.disciplines.isEmpty)
              _ProfileChip(
                icon: Icons.palette_outlined,
                label: isOwnProfile ? 'Define disciplinas' : 'Sin disciplinas',
              )
            else
              ...profile.disciplines.map(
                (discipline) => _ProfileChip(
                  icon: Icons.auto_awesome_outlined,
                  label: discipline,
                ),
              ),
            if (profile.country != null)
              _ProfileChip(
                  icon: Icons.public_outlined, label: profile.country!),
            if (profile.websiteUrl != null)
              _ProfileChip(
                icon: Icons.link_rounded,
                label: 'Sitio',
                onTap: () => onCopy(profile.websiteUrl!, 'Sitio'),
              ),
            if (profile.instagramHandle != null)
              _ProfileChip(
                icon: Icons.camera_alt_outlined,
                label: '@${profile.instagramHandle}',
                onTap: () => onCopy(profile.instagramHandle!, 'Instagram'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            statBuilder(worksCount, 'Obras'),
            statBuilder(followersCount, 'Seguidores'),
            statBuilder(profile.followingCount, 'Siguiendo'),
            statBuilder(collectionsCount, 'Colecciones'),
            statBuilder(profile.totalLikesReceived, 'Reconocimientos'),
          ],
        ),
      ],
    );
  }
}

class _ProfilePromptCard extends StatelessWidget {
  final bool hasBio;
  final bool hasDisciplines;
  final bool hasWorks;
  final VoidCallback onEdit;
  final VoidCallback onPublish;

  const _ProfilePromptCard({
    required this.hasBio,
    required this.hasDisciplines,
    required this.hasWorks,
    required this.onEdit,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final completed = [hasBio, hasDisciplines, hasWorks].where((v) => v).length;

    return CorvusSurface(
      color: Colors.black.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Preparar vitrina',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$completed/3',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileChecklistItem(done: hasBio, label: 'Escribe una bio breve'),
          _ProfileChecklistItem(
              done: hasDisciplines, label: 'Elige tus disciplinas'),
          _ProfileChecklistItem(done: hasWorks, label: 'Crea una obra'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPublish,
                  child: const Text('Crear obra'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileChecklistItem extends StatelessWidget {
  final bool done;
  final String label;

  const _ProfileChecklistItem({required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppColors.primary : AppColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done ? AppColors.textSecondary : AppColors.textMuted,
                fontSize: 12,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileIconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ProfileIconAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: CorvusSurface(
        padding: EdgeInsets.zero,
        color: Colors.black.withValues(alpha: 0.18),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ProfileChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: Colors.black.withValues(alpha: 0.16),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const _ProfileEmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CorvusSurface(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (actionText != null && onAction != null) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(actionText!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Puerta a los ritos de las casas cerradas sobre otro artista. La hoja decide
/// qué ritos mostrar según las casas que el usuario en sesión haya conquistado.
class _RitualInvokeCard extends StatelessWidget {
  final UserProfile profile;

  const _RitualInvokeCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ConspirationProvider>().accent;
    final name = profile.displayName.isNotEmpty
        ? profile.displayName
        : profile.username;

    return CorvusPanel(
      accent: accent,
      onTap: () => showConspiracyRitualsFor(
        context,
        targetProfileId: profile.id,
        targetName: name,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(CorvusRadius.sm),
              border: Border.all(color: accent.withValues(alpha: 0.32)),
            ),
            child: Icon(Icons.workspaces_outline, size: 18, color: accent),
          ),
          const SizedBox(width: CorvusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OFICIAR UN RITO', style: CorvusType.eyebrow(accent)),
                const SizedBox(height: 4),
                Text(
                  'Invitar al Pacto o respaldar su trayectoria',
                  style: CorvusType.muted,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded,
              size: 15, color: accent.withValues(alpha: 0.70)),
        ],
      ),
    );
  }
}
