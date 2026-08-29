import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/collection.dart';
import '../../models/work.dart';
import '../../providers/auth_provider.dart';
import '../../services/collection_service.dart';
import '../../services/work_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';
import '../../shared/widgets/work_card.dart';

class CollectionDetailPage extends StatefulWidget {
  final String collectionId;
  final Collection? initialCollection;
  final List<CollectionItem>? initialItems;
  final Map<String, String>? initialPrivateNotes;
  final String? initialProfileId;

  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    this.initialCollection,
    this.initialItems,
    this.initialPrivateNotes,
    this.initialProfileId,
  });

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  final _collectionService = CollectionService();
  Collection? _collection;
  List<CollectionItem> _items = [];
  Map<String, String> _privateNotes = {};
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isLikeBusy = false;
  bool _isOrganizing = false;
  String? _errorMessage;

  String? get _profileId =>
      widget.initialProfileId ?? context.read<AuthProvider>().profile?.id;
  bool get _isOwner => _collection?.isOwnedBy(_profileId) == true;

  @override
  void initState() {
    super.initState();
    if (widget.initialCollection != null) {
      _collection = widget.initialCollection;
      _items = List<CollectionItem>.from(widget.initialItems ?? const []);
      _privateNotes = Map<String, String>.from(
        widget.initialPrivateNotes ?? const {},
      );
      _isLoading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profileId = _profileId;
      final results = await Future.wait([
        _collectionService.getCollectionById(widget.collectionId),
        _collectionService.getCollectionItems(widget.collectionId),
        profileId == null
            ? Future.value(false)
            : _collectionService.isLiked(widget.collectionId, profileId),
        profileId == null
            ? Future.value(<String, String>{})
            : _collectionService.getPrivateNotes(widget.collectionId),
      ]);
      if (!mounted) return;
      setState(() {
        _collection = results[0] as Collection;
        _items = results[1] as List<CollectionItem>;
        _isLiked = results[2] as bool;
        _privateNotes = results[3] as Map<String, String>;
        _isLoading = false;
      });
      if (profileId != null) {
        _collectionService.recordView(widget.collectionId, profileId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'La colección no está disponible.';
      });
    }
  }

  Future<void> _toggleLike() async {
    final profileId = _profileId;
    final collection = _collection;
    if (profileId == null || collection == null || _isLikeBusy) return;
    final next = !_isLiked;
    setState(() {
      _isLiked = next;
      _isLikeBusy = true;
    });
    try {
      if (next) {
        await _collectionService.likeCollection(collection.id, profileId);
      } else {
        await _collectionService.unlikeCollection(collection.id, profileId);
      }
      if (!mounted) return;
      setState(() {
        _collection = collection.copyWith(
          likesCount: collection.likesCount + (next ? 1 : -1),
        );
        _isLikeBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = !next;
        _isLikeBusy = false;
      });
    }
  }

  Future<void> _editCollection() async {
    await context.push('/collection/${widget.collectionId}/edit');
    if (mounted) _load();
  }

  Future<void> _deleteCollection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar colección'),
        content: const Text(
          'La sala y sus notas curatoriales se eliminarán. Las obras originales no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _collectionService.deleteCollection(widget.collectionId);
      if (mounted) context.go('/collections');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la colección')),
      );
    }
  }

  Future<void> _editNote(CollectionItem item) async {
    final publicController = TextEditingController(text: item.note);
    final privateController = TextEditingController(
      text: _privateNotes[item.workId] ?? '',
    );
    final notes = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notas de la obra'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CorvusMarkdownFieldPreview(
                  controller: publicController,
                  child: TextField(
                    controller: publicController,
                    autofocus: true,
                    maxLines: 4,
                    maxLength: 600,
                    decoration: const InputDecoration(
                      labelText: 'Texto curatorial',
                      hintText: 'Contexto visible dentro de la colección',
                      prefixIcon: Icon(Icons.format_quote_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CorvusMarkdownFieldPreview(
                  controller: privateController,
                  child: TextField(
                    controller: privateController,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Nota personal',
                      hintText: 'Referencia o idea que solo tú puedes leer',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              (publicController.text.trim(), privateController.text.trim()),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    publicController.dispose();
    privateController.dispose();
    if (notes == null || _profileId == null) return;
    try {
      await Future.wait([
        _collectionService.updateCollectionItem(
          collectionId: item.collectionId,
          workId: item.workId,
          note: notes.$1,
        ),
        _collectionService.updatePrivateNote(
          collectionId: item.collectionId,
          workId: item.workId,
          profileId: _profileId!,
          note: notes.$2,
        ),
      ]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar las notas')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      final index =
          _items.indexWhere((current) => current.workId == item.workId);
      if (index >= 0) _items[index] = item.copyWith(note: notes.$1);
      if (notes.$2.isEmpty) {
        _privateNotes.remove(item.workId);
      } else {
        _privateNotes[item.workId] = notes.$2;
      }
    });
  }

  Future<void> _removeItem(CollectionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar obra'),
        content: Text(
          '“${item.work?.title ?? 'Esta obra'}” dejará de formar parte de la colección.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _collectionService.removeWorkFromCollection(
        item.collectionId,
        item.workId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar la obra')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _items.removeWhere((entry) => entry.workId == item.workId);
      _privateNotes.remove(item.workId);
      _collection = _collection?.copyWith(
        piecesCount: (_collection!.piecesCount - 1).clamp(0, 1 << 30),
      );
    });
  }

  Future<void> _addWorks() async {
    final collection = _collection;
    final profileId = _profileId;
    if (collection == null || profileId == null) return;
    final added = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _AddWorksSheet(
        collection: collection,
        profileId: profileId,
        existingWorkIds: _items.map((item) => item.workId).toSet(),
        collectionService: _collectionService,
      ),
    );
    if (added == null || added == 0 || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added == 1 ? 'Obra añadida' : '$added obras añadidas'),
      ),
    );
    await _load();
  }

  Future<void> _shareCollection() async {
    final collection = _collection;
    if (collection == null) return;
    final uri = Uri.base.replace(fragment: '/collection/${collection.id}');
    await Clipboard.setData(
      ClipboardData(text: '${collection.title}\n$uri'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace de la colección copiado')),
    );
  }

  Future<void> _moveItem(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
    try {
      await _collectionService.reorderCollectionItems(
        collectionId: widget.collectionId,
        workIds: _items.map((item) => item.workId).toList(),
      );
    } catch (_) {
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CorvusCrowLoader(label: 'Abriendo colección...')),
      );
    }
    if (_collection == null) return _buildUnavailable();
    final collection = _collection!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              expandedHeight: collection.coverUrl == null ? 0 : 280,
              leading: IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/collections'),
              ),
              actions: [
                IconButton(
                  tooltip: 'Compartir colección',
                  onPressed: _shareCollection,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
                IconButton(
                  tooltip: _isLiked ? 'Quitar de favoritos' : 'Me gusta',
                  onPressed: _toggleLike,
                  icon: Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isLiked ? AppColors.primary : null,
                  ),
                ),
                if (_isOwner)
                  PopupMenuButton<String>(
                    tooltip: 'Administrar colección',
                    onSelected: (value) {
                      if (value == 'edit') _editCollection();
                      if (value == 'delete') _deleteCollection();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Eliminar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
              flexibleSpace: collection.coverUrl == null
                  ? null
                  : FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: collection.coverUrl!,
                            fit: BoxFit.contain,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.background.withValues(alpha: 0.94),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            SliverToBoxAdapter(child: _buildHeader(collection)),
            if (_isOwner) SliverToBoxAdapter(child: _buildOwnerToolbar()),
            if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: CorvusEmptyState(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'Colección vacía',
                  subtitle: _isOwner
                      ? 'Añade obras desde su página pública para comenzar la sala.'
                      : 'El curador todavía no ha incorporado obras.',
                  actionText: _isOwner ? 'Descubrir obras' : null,
                  onAction: _isOwner ? _addWorks : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 1120
                        ? 4
                        : constraints.crossAxisExtent >= 760
                            ? 3
                            : constraints.crossAxisExtent >= 500
                                ? 2
                                : 1;
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _CollectionWorkTile(
                          item: _items[index],
                          isOwner: _isOwner,
                          isOrganizing: _isOrganizing,
                          privateNote:
                              _privateNotes[_items[index].workId] ?? '',
                          canMoveUp: index > 0,
                          canMoveDown: index < _items.length - 1,
                          onEditNote: () => _editNote(_items[index]),
                          onRemove: () => _removeItem(_items[index]),
                          onMoveUp: () => _moveItem(index, -1),
                          onMoveDown: () => _moveItem(index, 1),
                        ),
                        childCount: _items.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 18,
                        childAspectRatio: columns == 1 ? 0.86 : 0.62,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailable() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.go('/collections'),
        ),
      ),
      body: CorvusEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Colección no disponible',
        subtitle: _errorMessage ?? 'La colección no existe o es privada.',
        actionText: 'Volver a colecciones',
        onAction: () => context.go('/collections'),
      ),
    );
  }

  Widget _buildHeader(Collection collection) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _HeaderChip(label: collection.typeLabel),
              if (collection.isEditorial)
                const _HeaderChip(label: 'Selección editorial'),
              if (!collection.isPublic)
                const _HeaderChip(label: 'Privada', icon: Icons.lock_outline),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            collection.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Curada por ${collection.curatorLabel}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (collection.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Text(
                collection.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (collection.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: collection.tags
                  .map((tag) => _HeaderChip(label: '#$tag'))
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _HeaderMetric(
                icon: Icons.image_outlined,
                label: '${_items.length} obras',
              ),
              _HeaderMetric(
                icon: Icons.favorite_border_rounded,
                label: '${collection.likesCount} me gusta',
              ),
              _HeaderMetric(
                icon: Icons.visibility_outlined,
                label: '${collection.viewsCount} lectores',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildOwnerToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _addWorks,
            icon: const Icon(Icons.playlist_add_rounded, size: 19),
            label: const Text('Añadir obras'),
          ),
          if (_items.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => setState(() => _isOrganizing = !_isOrganizing),
              icon: Icon(
                _isOrganizing ? Icons.check_rounded : Icons.tune_rounded,
                size: 18,
              ),
              label: Text(_isOrganizing ? 'Terminar' : 'Organizar'),
            ),
        ],
      ),
    );
  }
}

class _CollectionWorkTile extends StatelessWidget {
  final CollectionItem item;
  final bool isOwner;
  final bool isOrganizing;
  final String privateNote;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEditNote;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _CollectionWorkTile({
    required this.item,
    required this.isOwner,
    required this.isOrganizing,
    required this.privateNote,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEditNote,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: WorkCard(work: item.work!)),
        if (item.note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.note,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.46),
              fontSize: 11,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (isOwner && privateNote.isNotEmpty) ...[
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  privateNote,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (isOwner && isOrganizing) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Subir',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.arrow_upward_rounded, size: 17),
              ),
              IconButton(
                tooltip: 'Bajar',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.arrow_downward_rounded, size: 17),
              ),
              IconButton(
                tooltip: 'Editar nota',
                onPressed: onEditNote,
                icon: const Icon(Icons.edit_note_rounded, size: 19),
              ),
              IconButton(
                tooltip: 'Quitar de la colección',
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _HeaderChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _AddWorksSheet extends StatefulWidget {
  final Collection collection;
  final String profileId;
  final Set<String> existingWorkIds;
  final CollectionService collectionService;

  const _AddWorksSheet({
    required this.collection,
    required this.profileId,
    required this.existingWorkIds,
    required this.collectionService,
  });

  @override
  State<_AddWorksSheet> createState() => _AddWorksSheetState();
}

class _AddWorksSheetState extends State<_AddWorksSheet> {
  final _workService = WorkService();
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  List<Work> _ownWorks = [];
  List<Work> _savedWorks = [];
  List<Work> _discoverWorks = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _query = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _workService.getOwnWorks(widget.profileId),
        _workService.getSavedWorks(widget.profileId),
        _workService.getDiscoverWorks(limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _ownWorks = _eligible(results[0]);
        _savedWorks = _eligible(results[1]);
        _discoverWorks = _eligible(results[2]);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No pudimos abrir tu biblioteca de obras.';
      });
    }
  }

  List<Work> _eligible(List<Work> works) {
    final byId = <String, Work>{};
    for (final work in works) {
      final canBePublic = work.isPublic && work.status == 'published';
      if (!widget.collection.isPublic || canBePublic) byId[work.id] = work;
    }
    return byId.values.toList();
  }

  List<Work> _filtered(List<Work> works) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return works;
    return works.where((work) {
      return [
        work.title,
        work.discipline,
        work.subdiscipline,
        work.authorDisplayName ?? '',
        work.authorUsername ?? '',
        ...work.tags,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  void _toggle(Work work) {
    if (widget.existingWorkIds.contains(work.id) || _isSaving) return;
    setState(() {
      if (!_selectedIds.add(work.id)) _selectedIds.remove(work.id);
    });
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.collectionService.addWorksToCollection(
        widget.collection.id,
        _selectedIds.toList(),
      );
      if (mounted) Navigator.pop(context, _selectedIds.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron añadir las obras')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Añadir obras',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar por título, autor o disciplina',
                    prefixIcon: const Icon(Icons.search_rounded),
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
                ),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(text: 'MIS OBRAS'),
                    Tab(text: 'GUARDADAS'),
                    Tab(text: 'DESCUBRIR'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildContent()),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedIds.isEmpty || _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add_rounded),
                    label: Text(
                      _selectedIds.isEmpty
                          ? 'Selecciona obras'
                          : 'Añadir ${_selectedIds.length}',
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_errorMessage != null) {
      return CorvusEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Biblioteca no disponible',
        subtitle: _errorMessage!,
        actionText: 'Reintentar',
        onAction: () {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
          _load();
        },
      );
    }
    return TabBarView(
      children: [
        _buildWorkList(_filtered(_ownWorks), 'No tienes obras disponibles'),
        _buildWorkList(_filtered(_savedWorks), 'No hay obras guardadas'),
        _buildWorkList(
          _filtered(_discoverWorks),
          'No encontramos obras públicas',
        ),
      ],
    );
  }

  Widget _buildWorkList(List<Work> works, String emptyLabel) {
    if (works.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: works.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final work = works[index];
        final exists = widget.existingWorkIds.contains(work.id);
        final selected = _selectedIds.contains(work.id);
        final author = (work.authorDisplayName?.trim().isNotEmpty ?? false)
            ? work.authorDisplayName!
            : (work.authorUsername?.trim().isNotEmpty ?? false)
                ? '@${work.authorUsername}'
                : 'Autor sin firma';
        return ListTile(
          onTap: exists ? null : () => _toggle(work),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 52,
              height: 52,
              child: work.displayImage.isEmpty
                  ? Container(
                      color: AppColors.overlay,
                      child: const Icon(Icons.image_outlined, size: 20),
                    )
                  : CachedNetworkImage(
                      imageUrl: work.displayImage,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.overlay,
                        child:
                            const Icon(Icons.broken_image_outlined, size: 20),
                      ),
                    ),
            ),
          ),
          title: Text(
            work.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${work.discipline.isEmpty ? 'Obra' : work.discipline} · $author',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: exists
              ? const Tooltip(
                  message: 'Ya pertenece a la colección',
                  child: Icon(Icons.check_circle_rounded,
                      color: AppColors.primary),
                )
              : Checkbox(
                  value: selected,
                  onChanged: (_) => _toggle(work),
                ),
        );
      },
    );
  }
}
