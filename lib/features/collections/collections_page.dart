import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/collection.dart';
import '../../providers/auth_provider.dart';
import '../../services/collection_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_empty_state.dart';

enum _CollectionSort { recent, liked, viewed, largest }

class CollectionsPage extends StatefulWidget {
  final List<Collection>? initialMyCollections;
  final List<Collection>? initialPublicCollections;
  final List<Collection>? initialFeaturedCollections;

  const CollectionsPage({
    super.key,
    this.initialMyCollections,
    this.initialPublicCollections,
    this.initialFeaturedCollections,
  });

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage>
    with SingleTickerProviderStateMixin {
  final _collectionService = CollectionService();
  final _searchController = TextEditingController();
  late final TabController _tabController;

  List<Collection> _myCollections = [];
  List<Collection> _publicCollections = [];
  List<Collection> _featuredCollections = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';
  String _typeFilter = 'all';
  _CollectionSort _sort = _CollectionSort.recent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialMyCollections != null ||
        widget.initialPublicCollections != null ||
        widget.initialFeaturedCollections != null) {
      _myCollections = widget.initialMyCollections ?? [];
      _publicCollections = widget.initialPublicCollections ?? [];
      _featuredCollections = widget.initialFeaturedCollections ?? [];
      _isLoading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = context.read<AuthProvider>().profile;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      var failures = 0;
      Future<List<Collection>> guarded(
        Future<List<Collection>> request,
      ) async {
        try {
          return await request;
        } catch (_) {
          failures += 1;
          return <Collection>[];
        }
      }

      final attemptedRequests = profile == null ? 2 : 3;
      final results = await Future.wait([
        profile == null
            ? Future.value(<Collection>[])
            : guarded(_collectionService.getUserCollections(profile.id)),
        guarded(_collectionService.getCollections(limit: 100)),
        guarded(_collectionService.getFeaturedCollections()),
      ]);
      if (!mounted) return;
      setState(() {
        _myCollections = results[0];
        _publicCollections = results[1];
        _featuredCollections = results[2];
        _isLoading = false;
        _errorMessage = failures == attemptedRequests
            ? 'No pudimos cargar las colecciones.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No pudimos cargar las colecciones.';
      });
    }
  }

  List<Collection> _filter(List<Collection> source) {
    final query = _query.trim().toLowerCase();
    final filtered = source.where((collection) {
      if (_typeFilter != 'all' && collection.collectionType != _typeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final searchable = [
        collection.title,
        collection.description,
        collection.curatorLabel,
        collection.typeLabel,
        ...collection.tags,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
    filtered.sort((a, b) {
      return switch (_sort) {
        _CollectionSort.recent => b.updatedAt.compareTo(a.updatedAt),
        _CollectionSort.liked => b.likesCount.compareTo(a.likesCount),
        _CollectionSort.viewed => b.viewsCount.compareTo(a.viewsCount),
        _CollectionSort.largest => b.piecesCount.compareTo(a.piecesCount),
      };
    });
    return filtered;
  }

  Future<void> _openCreate() async {
    await context.push('/collection/create');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(bottom: false, child: _buildHeader()),
            _buildSearch(),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 4),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'MÍAS (${_myCollections.length})'),
                Tab(text: 'DESCUBRIR (${_publicCollections.length})'),
                Tab(text: 'DESTACADAS (${_featuredCollections.length})'),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCollectionList(
                          _filter(_myCollections),
                          emptyTitle: 'Tu archivo curatorial está vacío',
                          emptySubtitle:
                              'Crea una colección y comienza a relacionar obras.',
                          showCreate: true,
                        ),
                        _buildCollectionList(
                          _filter(_publicCollections),
                          emptyTitle: 'No encontramos colecciones',
                          emptySubtitle:
                              'Prueba otra búsqueda o vuelve más tarde.',
                        ),
                        _buildCollectionList(
                          _filter(_featuredCollections),
                          emptyTitle: 'Aún no hay colecciones destacadas',
                          emptySubtitle:
                              'La selección editorial aparecerá aquí.',
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COLECCIONES',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.70),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Biblioteca y curaduría',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Obras reunidas por afinidad, memoria y contexto.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Nueva colección',
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar por título, etiqueta o curador',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      ('all', 'Todas'),
      ('curated', 'Curaduría'),
      ('personal', 'Personal'),
      ('inspiration', 'Inspiración'),
      ('series', 'Series'),
      ('exhibition', 'Exposiciones'),
    ];
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final filter = filters[index];
                return FilterChip(
                  label: Text(filter.$2),
                  selected: _typeFilter == filter.$1,
                  onSelected: (_) => setState(() => _typeFilter = filter.$1),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<_CollectionSort>(
          tooltip: 'Ordenar colecciones',
          initialValue: _sort,
          onSelected: (value) => setState(() => _sort = value),
          icon: const Icon(Icons.swap_vert_rounded),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _CollectionSort.recent,
              child: Text('Actividad reciente'),
            ),
            PopupMenuItem(
              value: _CollectionSort.liked,
              child: Text('Más apreciadas'),
            ),
            PopupMenuItem(
              value: _CollectionSort.viewed,
              child: Text('Más vistas'),
            ),
            PopupMenuItem(
              value: _CollectionSort.largest,
              child: Text('Más obras'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollectionList(
    List<Collection> collections, {
    required String emptyTitle,
    required String emptySubtitle,
    bool showCreate = false,
  }) {
    if (_errorMessage != null) {
      return _CollectionScrollState(
        child: CorvusEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No se pudieron abrir las colecciones',
          subtitle: _errorMessage!,
          actionText: 'Reintentar',
          onAction: _load,
        ),
      );
    }
    if (collections.isEmpty) {
      return _CollectionScrollState(
        child: CorvusEmptyState(
          icon: Icons.collections_bookmark_outlined,
          title: emptyTitle,
          subtitle: emptySubtitle,
          actionText: showCreate ? 'Crear colección' : null,
          onAction: showCreate ? _openCreate : null,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1120
              ? 4
              : constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 500
                      ? 2
                      : 1;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 1.65 : 0.88,
            ),
            itemCount: collections.length,
            itemBuilder: (_, index) => _CollectionCard(
              collection: collections[index],
              onReturn: _load,
            ),
          );
        },
      ),
    );
  }
}

class _CollectionScrollState extends StatelessWidget {
  final Widget child;

  const _CollectionScrollState({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 100),
      children: [child],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Collection collection;
  final VoidCallback onReturn;

  const _CollectionCard({required this.collection, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await context.push('/collection/${collection.id}');
        onReturn();
      },
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (collection.coverUrl != null)
                CachedNetworkImage(
                  imageUrl: collection.coverUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(color: AppColors.overlay),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.overlay),
                )
              else
                Container(
                  color: AppColors.overlay,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.collections_bookmark_outlined,
                    color: AppColors.primary.withValues(alpha: 0.38),
                    size: 42,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _CollectionBadge(label: collection.typeLabel),
                        if (collection.isFeatured ||
                            collection.isEditorial) ...[
                          const SizedBox(width: 6),
                          const _CollectionBadge(label: 'Destacada'),
                        ],
                        const Spacer(),
                        if (!collection.isPublic)
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      collection.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      collection.curatorLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _CollectionMetric(
                          icon: Icons.image_outlined,
                          value: collection.piecesCount,
                        ),
                        const SizedBox(width: 12),
                        _CollectionMetric(
                          icon: Icons.favorite_border_rounded,
                          value: collection.likesCount,
                        ),
                        const SizedBox(width: 12),
                        _CollectionMetric(
                          icon: Icons.visibility_outlined,
                          value: collection.viewsCount,
                        ),
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
}

class _CollectionBadge extends StatelessWidget {
  final String label;

  const _CollectionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryLight,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CollectionMetric extends StatelessWidget {
  final IconData icon;
  final int value;

  const _CollectionMetric({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.52)),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
