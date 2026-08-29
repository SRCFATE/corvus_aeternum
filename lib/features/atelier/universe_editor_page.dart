import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/atelier_models.dart';
import '../../models/collection.dart';
import '../../models/work.dart';
import '../../providers/atelier_provider.dart';
import '../../services/collection_service.dart';
import '../../services/work_service.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';

class UniverseEditorPage extends StatefulWidget {
  final String profileId;
  final String projectId;
  final AtelierNode? node;

  const UniverseEditorPage({
    super.key,
    required this.profileId,
    required this.projectId,
    this.node,
  });

  @override
  State<UniverseEditorPage> createState() => _UniverseEditorPageState();
}

class _UniverseEditorPageState extends State<UniverseEditorPage> {
  static const _metadataFields = <_UniverseField>[
    _UniverseField('world_scope', 'Alcance'),
    _UniverseField('creative_format', 'Formato matriz'),
    _UniverseField('main_genre', 'Genero base'),
    _UniverseField('target_audience', 'Publico objetivo'),
    _UniverseField('world_timeline', 'Linea temporal'),
    _UniverseField('internal_period', 'Periodo interno'),
    _UniverseField('world_regions', 'Regiones', lines: 3),
    _UniverseField('world_factions', 'Facciones', lines: 3),
    _UniverseField('world_systems', 'Sistemas', lines: 3),
    _UniverseField('world_rules', 'Reglas internas', lines: 4),
    _UniverseField('main_theme', 'Tema principal'),
    _UniverseField('secondary_themes', 'Temas secundarios', lines: 3),
    _UniverseField('emotional_tone', 'Tono emocional'),
    _UniverseField('atmosphere', 'Atmosfera'),
    _UniverseField('aesthetic', 'Estetica'),
    _UniverseField('symbols', 'Simbolos'),
    _UniverseField('inspirations', 'Inspiraciones', lines: 3),
    _UniverseField('references', 'Referencias', lines: 3),
  ];

  late final _titleController =
      TextEditingController(text: widget.node?.title ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.node?.body ?? '');
  late final _tagsController =
      TextEditingController(text: widget.node?.tags.join(', ') ?? '');
  late final Map<String, TextEditingController> _controllers = {
    for (final field in _metadataFields)
      field.key: TextEditingController(text: _metadataText(field.key)),
  };
  late String _status = widget.node?.status ?? 'active';
  late String _canonStatus = widget.node?.canonStatus ?? 'canon';
  late final Set<String> _linkedWorkIds = _stringSet('linked_work_ids');
  late final Set<String> _linkedCollectionIds =
      _stringSet('linked_collection_ids');
  late final Map<String, Map<String, dynamic>> _linkSettings = _settings();
  late final List<_LinkedMedium> _media = _linkedMedia();

  List<Work> _works = const [];
  List<Collection> _collections = const [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  String _metadataText(String key) {
    final value = widget.node?.metadata[key];
    return value == null ? '' : '$value';
  }

  Set<String> _stringSet(String key) {
    final raw = widget.node?.metadata[key];
    if (raw is! List) return <String>{};
    return raw.map((item) => '$item').where((item) => item.isNotEmpty).toSet();
  }

  Map<String, Map<String, dynamic>> _settings() {
    final raw = widget.node?.metadata['universe_link_settings'];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        '${entry.key}': entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{},
    };
  }

  List<_LinkedMedium> _linkedMedia() {
    final raw = widget.node?.metadata['linked_media'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => _LinkedMedium.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _loadLibrary() async {
    try {
      final results = await Future.wait([
        WorkService().getOwnWorks(widget.profileId),
        CollectionService().getCollections(
          profileId: widget.profileId,
          publicOnly: false,
          limit: 100,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _works = results[0] as List<Work>;
        _collections = results[1] as List<Collection>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = '$error';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El universo necesita un nombre.')),
      );
      return;
    }
    setState(() => _saving = true);
    final metadata = <String, dynamic>{
      if (widget.node != null) ...widget.node!.metadata,
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
      'universe_card': true,
      'universe_card_version': 2,
      'linked_work_ids': _linkedWorkIds.toList(),
      'linked_collection_ids': _linkedCollectionIds.toList(),
      'linked_media': _media.map((item) => item.toMap()).toList(),
      'universe_link_settings': _linkSettings,
    };
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    final provider = context.read<AtelierProvider>();
    try {
      if (widget.node == null) {
        await provider.createNode(
          profileId: widget.profileId,
          projectId: widget.projectId,
          kind: 'universe',
          title: _titleController.text,
          body: _descriptionController.text,
          status: _status,
          canonStatus: _canonStatus,
          tags: tags,
          metadata: metadata,
        );
      } else {
        await provider.updateNode(widget.node!.copyWith(
          kind: 'universe',
          title: _titleController.text,
          body: _descriptionController.text,
          status: _status,
          canonStatus: _canonStatus,
          tags: tags,
          metadata: metadata,
        ));
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el universo: $error')),
      );
    }
  }

  Future<void> _pickWorks() async {
    final selected = Set<String>.from(_linkedWorkIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _LinkPickerDialog<Work>(
        title: 'Vincular obras',
        items: _works,
        selectedIds: selected,
        idOf: (work) => work.id,
        titleOf: (work) => work.title,
        subtitleOf: (work) => [work.discipline, work.year]
            .where((value) => value != null && '$value'.isNotEmpty)
            .join(' - '),
        imageOf: (work) => work.displayImage,
      ),
    );
    if (result == null) return;
    setState(() {
      _linkedWorkIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _pickCollections() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _LinkPickerDialog<Collection>(
        title: 'Vincular colecciones',
        items: _collections,
        selectedIds: Set<String>.from(_linkedCollectionIds),
        idOf: (collection) => collection.id,
        titleOf: (collection) => collection.title,
        subtitleOf: (collection) =>
            '${collection.piecesCount} piezas - ${collection.typeLabel}',
        imageOf: (collection) => collection.coverUrl ?? '',
      ),
    );
    if (result == null) return;
    setState(() {
      _linkedCollectionIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _addMedium() async {
    final title = TextEditingController();
    final url = TextEditingController();
    final description = TextEditingController();
    var type = 'Libro';
    final result = await showDialog<_LinkedMedium>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vincular otro medio'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Titulo')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de medio'),
                    items: const [
                      'Libro',
                      'Videojuego',
                      'Articulo',
                      'Podcast',
                      'Pelicula',
                      'Sitio web',
                      'Otro'
                    ]
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: url,
                      decoration:
                          const InputDecoration(labelText: 'Enlace externo')),
                  const SizedBox(height: 12),
                  CorvusMarkdownFieldPreview(
                    controller: description,
                    child: TextField(
                        controller: description,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'Descripcion')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  _LinkedMedium(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    title: title.text.trim(),
                    type: type,
                    url: url.text.trim(),
                    description: description.text.trim(),
                    canonStatus: 'canon',
                  ),
                );
              },
              child: const Text('Vincular'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    url.dispose();
    description.dispose();
    if (result != null && mounted) setState(() => _media.add(result));
  }

  Map<String, dynamic> _settingFor(String id) => _linkSettings.putIfAbsent(
        id,
        () => <String, dynamic>{
          'relation_type': 'Historia principal',
          'canon_status': 'canon'
        },
      );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title:
              Text(widget.node == null ? 'Nuevo universo' : widget.node!.title),
          actions: [
            if (compact)
              IconButton.filledTonal(
                tooltip: 'Guardar universo',
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 18),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'Guardando' : 'Guardar universo'),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.public_rounded), text: 'Identidad y mundo'),
              Tab(icon: Icon(Icons.link_rounded), text: 'Contenido vinculado'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildIdentity(),
            _buildLinkedContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UniverseFormSection(
                title: 'Identidad del universo',
                icon: Icons.fingerprint_rounded,
                child: Column(
                  children: [
                    TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                            labelText: 'Nombre del universo')),
                    const SizedBox(height: 12),
                    CorvusMarkdownFieldPreview(
                      controller: _descriptionController,
                      child: TextField(
                          controller: _descriptionController,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                              labelText: 'Descripcion base')),
                    ),
                    const SizedBox(height: 12),
                    _UniverseFieldGrid(
                        fields: _metadataFields.take(4).toList(),
                        controllers: _controllers),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _UniverseFormSection(
                title: 'Mundo y continuidad',
                icon: Icons.travel_explore_rounded,
                child: _UniverseFieldGrid(
                    fields: _metadataFields.skip(4).take(6).toList(),
                    controllers: _controllers),
              ),
              const SizedBox(height: 14),
              _UniverseFormSection(
                title: 'Tono y estetica',
                icon: Icons.auto_awesome_outlined,
                child: _UniverseFieldGrid(
                    fields: _metadataFields.skip(10).toList(),
                    controllers: _controllers),
              ),
              const SizedBox(height: 14),
              _UniverseFormSection(
                title: 'Archivo y canon',
                icon: Icons.inventory_2_outlined,
                child: Column(
                  children: [
                    TextField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                            labelText: 'Etiquetas separadas por coma')),
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 620;
                      final fields = [
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration:
                              const InputDecoration(labelText: 'Estado'),
                          items: const [
                            'idea',
                            'active',
                            'draft',
                            'review',
                            'done',
                            'archived'
                          ]
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _status = value ?? _status),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _canonStatus,
                          decoration:
                              const InputDecoration(labelText: 'Canon general'),
                          items: const [
                            'canon',
                            'semi-canon',
                            'no-canon',
                            'draft',
                            'alternate',
                            'retcon'
                          ]
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setState(
                              () => _canonStatus = value ?? _canonStatus),
                        ),
                      ];
                      if (!wide) {
                        return Column(children: [
                          fields[0],
                          const SizedBox(height: 12),
                          fields[1]
                        ]);
                      }
                      return Row(children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[1])
                      ]);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedContent() {
    if (_loading) {
      return const Center(
          child: CorvusCrowLoader(label: 'Abriendo biblioteca del universo'));
    }
    if (_loadError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 36, color: AppColors.warning),
              const SizedBox(height: 12),
              Text('No se pudo abrir la biblioteca.\n$_loadError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _loadLibrary,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final linkedWorks =
        _works.where((work) => _linkedWorkIds.contains(work.id)).toList();
    final microStories = linkedWorks.where(_isMicroStory).toList();
    final stories = linkedWorks.where((work) => !_isMicroStory(work)).toList();
    final linkedCollections = _collections
        .where((collection) => _linkedCollectionIds.contains(collection.id))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Archivo transmedia',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text(
                  'Reune las obras, relatos, colecciones y medios que comparten esta continuidad.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              _LinkedSection<Work>(
                title: 'Historias vinculadas',
                icon: Icons.auto_stories_outlined,
                items: stories,
                emptyMessage:
                    'Aun no hay historias vinculadas a este universo.',
                actionLabel: 'Vincular obras',
                onAdd: _pickWorks,
                itemBuilder: (work) => _LinkedWorkTile(
                  work: work,
                  setting: _settingFor(work.id),
                  onChanged: () => setState(() {}),
                  onRemove: () =>
                      setState(() => _linkedWorkIds.remove(work.id)),
                ),
              ),
              const SizedBox(height: 18),
              _LinkedSection<Work>(
                title: 'Microrrelatos vinculados',
                icon: Icons.short_text_rounded,
                items: microStories,
                emptyMessage: 'No hay microrrelatos vinculados.',
                actionLabel: 'Vincular microrrelato',
                onAdd: _pickWorks,
                itemBuilder: (work) => _LinkedWorkTile(
                  work: work,
                  setting: _settingFor(work.id),
                  onChanged: () => setState(() {}),
                  onRemove: () =>
                      setState(() => _linkedWorkIds.remove(work.id)),
                ),
              ),
              const SizedBox(height: 18),
              _LinkedSection<Collection>(
                title: 'Colecciones vinculadas',
                icon: Icons.collections_bookmark_outlined,
                items: linkedCollections,
                emptyMessage: 'No hay colecciones vinculadas.',
                actionLabel: 'Vincular coleccion',
                onAdd: _pickCollections,
                itemBuilder: (collection) => _LinkedCollectionTile(
                  collection: collection,
                  onRemove: () => setState(
                      () => _linkedCollectionIds.remove(collection.id)),
                ),
              ),
              const SizedBox(height: 18),
              _LinkedSection<_LinkedMedium>(
                title: 'Otros medios vinculados',
                icon: Icons.language_rounded,
                items: _media,
                emptyMessage:
                    'No hay libros, videojuegos, articulos u otros medios vinculados.',
                actionLabel: 'Vincular medio',
                onAdd: _addMedium,
                itemBuilder: (medium) => _LinkedMediumTile(
                  medium: medium,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _media.remove(medium)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isMicroStory(Work work) {
    final source =
        '${work.discipline} ${work.subdiscipline} ${work.tags.join(' ')}'
            .toLowerCase();
    return source.contains('microrelato') || source.contains('microcuento');
  }
}

class _UniverseField {
  final String key;
  final String label;
  final int lines;
  const _UniverseField(this.key, this.label, {this.lines = 1});
}

class _UniverseFieldGrid extends StatelessWidget {
  final List<_UniverseField> fields;
  final Map<String, TextEditingController> controllers;
  const _UniverseFieldGrid({required this.fields, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: fields
            .map((field) => SizedBox(
                  width: width,
                  child: TextField(
                    controller: controllers[field.key],
                    minLines: field.lines,
                    maxLines: field.lines + 2,
                    decoration: InputDecoration(
                        labelText: field.label,
                        alignLabelWithHint: field.lines > 1),
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _UniverseFormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _UniverseFormSection(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w900))
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LinkedSection<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<T> items;
  final String emptyMessage;
  final String actionLabel;
  final VoidCallback onAdd;
  final Widget Function(T) itemBuilder;

  const _LinkedSection(
      {required this.title,
      required this.icon,
      required this.items,
      required this.emptyMessage,
      required this.actionLabel,
      required this.onAdd,
      required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.gold),
              const SizedBox(width: 9),
              Expanded(
                  child: Text('$title (${items.length})',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900))),
              OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: Text(actionLabel)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyMessage,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            ...items.map(itemBuilder),
        ],
      ),
    );
  }
}

class _LinkedWorkTile extends StatelessWidget {
  final Work work;
  final Map<String, dynamic> setting;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _LinkedWorkTile(
      {required this.work,
      required this.setting,
      required this.onChanged,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _LinkedTileShell(
      imageUrl: work.displayImage,
      fallbackIcon: Icons.auto_stories_outlined,
      title: work.title,
      subtitle: [work.discipline, work.year]
          .where((value) => value != null && '$value'.isNotEmpty)
          .join(' - '),
      onRemove: onRemove,
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              initialValue:
                  setting['relation_type'] as String? ?? 'Historia principal',
              decoration: const InputDecoration(
                  labelText: 'Tipo de historia', isDense: true),
              items: const [
                'Historia principal',
                'Historia paralela',
                'Precuela',
                'Secuela',
                'Antologia',
                'Adaptacion'
              ]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                setting['relation_type'] = value;
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: setting['canon_status'] as String? ?? 'canon',
              decoration:
                  const InputDecoration(labelText: 'Canon', isDense: true),
              items: const ['canon', 'semi-canon', 'alternate', 'no-canon']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                setting['canon_status'] = value;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedCollectionTile extends StatelessWidget {
  final Collection collection;
  final VoidCallback onRemove;
  const _LinkedCollectionTile(
      {required this.collection, required this.onRemove});
  @override
  Widget build(BuildContext context) => _LinkedTileShell(
        imageUrl: collection.coverUrl ?? '',
        fallbackIcon: Icons.collections_bookmark_outlined,
        title: collection.title,
        subtitle: '${collection.piecesCount} piezas - ${collection.typeLabel}',
        onRemove: onRemove,
        controls: Text(
            collection.isPublic ? 'Coleccion publica' : 'Coleccion privada',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
}

class _LinkedMediumTile extends StatelessWidget {
  final _LinkedMedium medium;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _LinkedMediumTile(
      {required this.medium, required this.onChanged, required this.onRemove});
  @override
  Widget build(BuildContext context) => _LinkedTileShell(
        imageUrl: '',
        fallbackIcon: Icons.language_rounded,
        title: medium.title,
        subtitle:
            '${medium.type}${medium.url.isEmpty ? '' : ' - ${medium.url}'}',
        onRemove: onRemove,
        controls: SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            initialValue: medium.canonStatus,
            decoration:
                const InputDecoration(labelText: 'Canon', isDense: true),
            items: const ['canon', 'semi-canon', 'alternate', 'no-canon']
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) {
              medium.canonStatus = value ?? medium.canonStatus;
              onChanged();
            },
          ),
        ),
      );
}

class _LinkedTileShell extends StatelessWidget {
  final String imageUrl;
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final Widget controls;
  final VoidCallback onRemove;
  const _LinkedTileShell(
      {required this.imageUrl,
      required this.fallbackIcon,
      required this.title,
      required this.subtitle,
      required this.controls,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.028),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 10),
            controls,
          ],
        );
        final image = _LinkCover(imageUrl: imageUrl, icon: fallbackIcon);
        final remove = IconButton(
            tooltip: 'Desvincular',
            onPressed: onRemove,
            icon: const Icon(Icons.link_off_rounded, size: 19));
        if (narrow) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            image,
            const SizedBox(width: 12),
            Expanded(child: info),
            remove
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          image,
          const SizedBox(width: 14),
          Expanded(child: info),
          remove
        ]);
      }),
    );
  }
}

class _LinkCover extends StatelessWidget {
  final String imageUrl;
  final IconData icon;
  final double width;
  final double height;
  const _LinkCover({
    required this.imageUrl,
    required this.icon,
    this.width = 78,
    this.height = 104,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl.isEmpty
            ? ColoredBox(
                color: AppColors.cardElevated,
                child: Icon(icon, color: AppColors.gold, size: 28))
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
                    color: AppColors.cardElevated,
                    child: Icon(icon, color: AppColors.gold))),
      ),
    );
  }
}

class _LinkPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final Set<String> selectedIds;
  final String Function(T) idOf;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final String Function(T) imageOf;
  const _LinkPickerDialog(
      {required this.title,
      required this.items,
      required this.selectedIds,
      required this.idOf,
      required this.titleOf,
      required this.subtitleOf,
      required this.imageOf});
  @override
  State<_LinkPickerDialog<T>> createState() => _LinkPickerDialogState<T>();
}

class _LinkPickerDialogState<T> extends State<_LinkPickerDialog<T>> {
  late final Set<String> selected = Set<String>.from(widget.selectedIds);
  String query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((item) =>
            widget.titleOf(item).toLowerCase().contains(query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 620,
        height: 480,
        child: Column(
          children: [
            TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Buscar en tu biblioteca')),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No hay elementos disponibles.',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final id = widget.idOf(item);
                        return CheckboxListTile(
                          value: selected.contains(id),
                          onChanged: (value) => setState(() => value == true
                              ? selected.add(id)
                              : selected.remove(id)),
                          secondary: _LinkCover(
                              imageUrl: widget.imageOf(item),
                              icon: Icons.image_outlined,
                              width: 40,
                              height: 52),
                          title: Text(widget.titleOf(item),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(widget.subtitleOf(item),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: Text('Vincular (${selected.length})')),
      ],
    );
  }
}

class _LinkedMedium {
  final String id;
  final String title;
  final String type;
  final String url;
  final String description;
  String canonStatus;
  _LinkedMedium(
      {required this.id,
      required this.title,
      required this.type,
      required this.url,
      required this.description,
      required this.canonStatus});
  factory _LinkedMedium.fromMap(Map<String, dynamic> map) => _LinkedMedium(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Medio sin titulo',
      type: map['type'] as String? ?? 'Otro',
      url: map['url'] as String? ?? '',
      description: map['description'] as String? ?? '',
      canonStatus: map['canon_status'] as String? ?? 'canon');
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'url': url,
        'description': description,
        'canon_status': canonStatus
      };
}
