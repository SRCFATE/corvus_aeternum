import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/collection.dart';
import '../../models/work.dart';
import '../../services/collection_service.dart';

Future<void> showAddToCollection(BuildContext context,
    {required Work work,
    required String? profileId,
    CollectionService? service}) async {
  if (profileId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para usar colecciones')));
    return;
  }
  final repository = service ?? CollectionService();
  try {
    final collections = (await repository.getUserCollections(profileId))
        .where((collection) =>
            !collection.isPublic ||
            (work.isPublic && work.status == 'published'))
        .toList();
    final ids = await repository.getCollectionIdsForWork(
        work.id, collections.map((collection) => collection.id).toList());
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AddToCollectionSheet(
            collections: collections,
            initialCollectionIds: ids,
            workId: work.id,
            profileId: profileId,
            collectionService: repository));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No se pudieron abrir tus colecciones. Inténtalo de nuevo.')));
    }
  }
}

class _AddToCollectionSheet extends StatefulWidget {
  final List<Collection> collections;
  final Set<String> initialCollectionIds;
  final String workId;
  final String profileId;
  final CollectionService collectionService;

  const _AddToCollectionSheet({
    required this.collections,
    required this.initialCollectionIds,
    required this.workId,
    required this.profileId,
    required this.collectionService,
  });

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  late List<Collection> _collections;
  late Set<String> _collectionIds;
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  bool _showCreate = false;
  bool _creating = false;
  String? _busyCollectionId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _collections = List<Collection>.from(widget.collections);
    _collectionIds = Set<String>.from(widget.initialCollectionIds);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addToCollection(Collection collection) async {
    final wasIncluded = _collectionIds.contains(collection.id);
    setState(() => _busyCollectionId = collection.id);
    try {
      if (wasIncluded) {
        await widget.collectionService.removeWorkFromCollection(
          collection.id,
          widget.workId,
        );
      } else {
        await widget.collectionService.addWorkToCollection(
          collection.id,
          widget.workId,
        );
      }
      if (!mounted) return;
      setState(() {
        _busyCollectionId = null;
        final index =
            _collections.indexWhere((item) => item.id == collection.id);
        if (wasIncluded) {
          _collectionIds.remove(collection.id);
        } else {
          _collectionIds.add(collection.id);
        }
        if (index >= 0) {
          _collections[index] = collection.copyWith(
            piecesCount: (collection.piecesCount + (wasIncluded ? -1 : 1))
                .clamp(0, 1 << 30),
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasIncluded
                ? 'Obra retirada de ${collection.title}'
                : 'Obra añadida a ${collection.title}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyCollectionId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo añadir a la colección')),
      );
    }
  }

  Future<void> _createCollectionAndAdd() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la colección')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final collection = await widget.collectionService.createCollection(
        profileId: widget.profileId,
        title: title,
        description: '',
        isPublic: false,
      );
      await widget.collectionService
          .addWorkToCollection(collection.id, widget.workId);
      if (!mounted) return;
      setState(() {
        _collections.insert(0, collection.copyWith(piecesCount: 1));
        _collectionIds.add(collection.id);
        _showCreate = false;
        _creating = false;
        _titleController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Colección "$title" creada')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la colección')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visibleCollections = query.isEmpty
        ? _collections
        : _collections
            .where(
              (collection) => [
                collection.title,
                collection.typeLabel,
                ...collection.tags,
              ].join(' ').toLowerCase().contains(query),
            )
            .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Añadir a colección',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _showCreate = !_showCreate);
                    },
                    icon: Icon(
                      _showCreate ? Icons.close_rounded : Icons.add_rounded,
                      size: 17,
                    ),
                    label: Text(_showCreate ? 'Cancelar' : 'Nueva'),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_showCreate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Nombre de colección',
                            counterText: '',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.32),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          maxLength: 120,
                          onSubmitted: (_) => _createCollectionAndAdd(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _creating
                          ? const SizedBox(
                              width: 34,
                              height: 34,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _createCollectionAndAdd,
                              icon: const Icon(Icons.check_rounded),
                              color: AppColors.primary,
                            ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Buscar colección',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
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
              if (visibleCollections.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    _collections.isEmpty
                        ? 'No tienes colecciones aún.'
                        : 'No encontramos colecciones.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibleCollections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final collection = visibleCollections[index];
                      final busy = _busyCollectionId == collection.id;
                      final included = _collectionIds.contains(collection.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: busy ? null : () => _addToCollection(collection),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.035),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.collections_bookmark_outlined,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      collection.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${collection.piecesCount} piezas · ${collection.isPublic ? 'pública' : 'privada'}',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.36),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (busy)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              else
                                Icon(
                                  included
                                      ? Icons.check_circle_rounded
                                      : Icons.add_circle_outline_rounded,
                                  color: included
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
