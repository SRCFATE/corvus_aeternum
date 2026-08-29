import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/router/navigation_coordinator.dart';
import '../../models/atelier_models.dart';
import '../../providers/atelier_provider.dart';
import '../../shared/widgets/corvus_text_field.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';

class CharacterEditorPage extends StatefulWidget {
  final String profileId;
  final String projectId;
  final AtelierNode? node;

  const CharacterEditorPage({
    super.key,
    required this.profileId,
    required this.projectId,
    this.node,
  });

  @override
  State<CharacterEditorPage> createState() => _CharacterEditorPageState();
}

class _CharacterEditorPageState extends State<CharacterEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _tagsController;
  final Map<String, TextEditingController> _fieldControllers = {};

  late AtelierNode? _node = widget.node;
  late String _template = _initialTemplate;
  late String _status = widget.node?.status ?? 'draft';
  late String _canonStatus = widget.node?.canonStatus ?? 'canon';
  late final List<_CharacterMoment> _timeline = _readTimeline();
  bool _dirty = false;
  bool _saving = false;

  String get _initialTemplate {
    final value = widget.node?.metadata['character_template'] as String?;
    return _templateRanks.containsKey(value) ? value! : 'narrative';
  }

  Map<String, dynamic> get _storedSheet {
    final value = widget.node?.metadata['character_sheet'];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.node?.title ?? '');
    _bodyController = TextEditingController(text: widget.node?.body ?? '');
    _tagsController =
        TextEditingController(text: widget.node?.tags.join(', ') ?? '');
    for (final field
        in _characterSections.expand((section) => section.fields)) {
      final stored =
          _storedSheet[field.key] ?? widget.node?.metadata[field.key];
      _fieldControllers[field.key] =
          TextEditingController(text: stored == null ? '' : '$stored');
    }
    for (final controller in [
      _titleController,
      _bodyController,
      _tagsController,
      ..._fieldControllers.values,
    ]) {
      controller.addListener(_markDirty);
    }
    AppNavigationCoordinator.instance.registerExitGuard(
      this,
      _confirmNavigationExit,
    );
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    AppNavigationCoordinator.instance.unregisterExitGuard(this);
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_CharacterMoment> _readTimeline() {
    final source = widget.node?.metadata['character_timeline'];
    if (source is! List) return [];
    return source
        .map(_CharacterMoment.fromDynamic)
        .whereType<_CharacterMoment>()
        .toList();
  }

  List<String> get _tags => _tagsController.text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();

  Map<String, dynamic> _metadata() {
    final sheet = <String, dynamic>{};
    for (final entry in _fieldControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) sheet[entry.key] = value;
    }
    return {
      if (_node != null) ..._node!.metadata,
      'character_template': _template,
      'character_sheet': sheet,
      'character_timeline': _timeline.map((moment) => moment.toMap()).toList(),
    };
  }

  Future<bool> _save() async {
    if (_saving) return false;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _message('Escribe el nombre del personaje.');
      return false;
    }
    setState(() => _saving = true);
    final provider = context.read<AtelierProvider>();
    try {
      if (_node == null) {
        _node = await provider.createNode(
          profileId: widget.profileId,
          projectId: widget.projectId,
          kind: 'character',
          title: title,
          body: _bodyController.text,
          status: _status,
          canonStatus: _canonStatus,
          tags: _tags,
          metadata: _metadata(),
        );
      } else {
        await provider.updateNode(
          _node!.copyWith(
            title: title,
            body: _bodyController.text,
            status: _status,
            canonStatus: _canonStatus,
            tags: _tags,
            metadata: _metadata(),
          ),
        );
        _node = provider.nodeById(_node!.id) ?? _node;
      }
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      _message('Ficha guardada.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _saving = false);
      _message('No se pudo guardar: $error');
      return false;
    }
  }

  Future<void> _delete() async {
    if (_node == null) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar personaje'),
        content: Text(
          'Se eliminara "${_node!.title}" y sus relaciones. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AtelierProvider>().deleteNode(widget.profileId, _node!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _close() async {
    final canClose = await _confirmNavigationExit();
    if (!canClose || !mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmNavigationExit() async {
    if (!_dirty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('¿Deseas salir de la ficha?'),
          content: const Text(
            'No hay cambios pendientes. Volverás al espacio de trabajo de Atelier.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      return confirmed == true;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Salir de la ficha'),
        content: const Text('Hay cambios sin guardar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('stay'),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Guardar y salir'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    switch (choice) {
      case 'save':
        return _save();
      case 'discard':
        setState(() => _dirty = false);
        return true;
      default:
        return false;
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editMoment([_CharacterMoment? existing]) async {
    final dateController = TextEditingController(text: existing?.date ?? '');
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final result = await showDialog<_CharacterMoment>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(existing == null ? 'Nuevo momento' : 'Editar momento'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CorvusTextField(
                  controller: dateController,
                  label: 'Fecha, era o edad',
                  hint: 'Ej. Ano 12, infancia, despues del exilio',
                ),
                const SizedBox(height: 14),
                CorvusTextField(
                  controller: titleController,
                  label: 'Momento',
                ),
                const SizedBox(height: 14),
                CorvusTextField(
                  controller: descriptionController,
                  label: 'Consecuencia narrativa',
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;
              Navigator.of(context).pop(
                _CharacterMoment(
                  id: existing?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  date: dateController.text.trim(),
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    dateController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      final index = _timeline.indexWhere((moment) => moment.id == result.id);
      if (index == -1) {
        _timeline.add(result);
      } else {
        _timeline[index] = result;
      }
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(compact),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 36,
                    24,
                    compact ? 16 : 36,
                    72,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeading(compact),
                            const SizedBox(height: 28),
                            _buildTemplatePicker(),
                            const SizedBox(height: 22),
                            ..._characterSections
                                .where((section) =>
                                    section.minimumRank <=
                                    _templateRanks[_template]!)
                                .map(_buildSection),
                            _buildTimeline(),
                            if (_node != null) _buildRelations(),
                          ],
                        ),
                      ),
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

  Widget _buildTopBar(bool compact) {
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: _saving ? null : _close,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.badge_outlined, color: AppColors.gold, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              compact ? 'Personaje' : 'Ficha de personaje',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_node != null)
            IconButton(
              tooltip: 'Eliminar personaje',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 17),
            label: Text(compact ? 'Guardar' : 'Guardar ficha'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.node == null ? 'Nuevo personaje' : 'Dossier narrativo',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: compact ? 26 : 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!compact)
              Text(
                _dirty ? 'Cambios sin guardar' : 'Ficha al dia',
                style: TextStyle(
                  color: _dirty ? AppColors.gold : AppColors.successLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        CorvusTextField(
          controller: _titleController,
          label: 'Nombre',
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
        const SizedBox(height: 16),
        CorvusTextField(
          controller: _bodyController,
          label: 'Presentacion o biografia',
          hint: 'Puedes escribir esta seccion con Markdown.',
          maxLines: 7,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final status = _SelectField(
              label: 'Estado',
              value: _status,
              values: const {
                'idea': 'Idea',
                'draft': 'Borrador',
                'active': 'Activo',
                'review': 'En revision',
                'done': 'Terminado',
                'archived': 'Archivado',
              },
              onChanged: (value) => setState(() {
                _status = value;
                _dirty = true;
              }),
            );
            final canon = _SelectField(
              label: 'Continuidad',
              value: _canonStatus,
              values: const {
                'canon': 'Canon',
                'semi-canon': 'Semi-canon',
                'alternate': 'Alternativo',
                'draft': 'Borrador',
                'no-canon': 'No canon',
              },
              onChanged: (value) => setState(() {
                _canonStatus = value;
                _dirty = true;
              }),
            );
            final tags = CorvusTextField(
              controller: _tagsController,
              label: 'Etiquetas',
              hint: 'protagonista, casa norte, orden carmesi',
            );
            if (!wide) {
              return Column(
                children: [
                  status,
                  const SizedBox(height: 14),
                  canon,
                  const SizedBox(height: 14),
                  tags,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: status),
                const SizedBox(width: 14),
                Expanded(child: canon),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: tags),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTemplatePicker() {
    return _CharacterSection(
      icon: Icons.view_quilt_outlined,
      title: 'Plantilla de ficha',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: _templateDefinitions.map((definition) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: definition == _templateDefinitions.last ? 0 : 8,
                  ),
                  child: _TemplateChoice(
                    definition: definition,
                    selected: _template == definition.id,
                    onTap: () => setState(() {
                      _template = definition.id;
                      _dirty = true;
                    }),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildSection(_CharacterFieldSection section) {
    final fields = section.fields
        .where((field) => field.minimumRank <= _templateRanks[_template]!)
        .toList();
    return _CharacterSection(
      icon: section.icon,
      title: section.title,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 760;
          final width = twoColumns
              ? (constraints.maxWidth - 14) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 14,
            runSpacing: 16,
            children: fields.map((field) {
              return SizedBox(
                width: field.expanded ? constraints.maxWidth : width,
                child: CorvusTextField(
                  controller: _fieldControllers[field.key]!,
                  label: field.label,
                  hint: field.hint,
                  maxLines: field.lines,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTimeline() {
    return _CharacterSection(
      icon: Icons.timeline_rounded,
      title: 'Linea de tiempo',
      trailing: IconButton.filledTonal(
        tooltip: 'Agregar momento',
        onPressed: _editMoment,
        icon: const Icon(Icons.add_rounded),
      ),
      child: _timeline.isEmpty
          ? _CharacterEmptyState(
              icon: Icons.history_toggle_off_rounded,
              text: 'Aun no hay momentos registrados.',
              buttonLabel: 'Agregar momento',
              onPressed: _editMoment,
            )
          : Column(
              children: _timeline.asMap().entries.map((entry) {
                final moment = entry.value;
                return _TimelineRow(
                  moment: moment,
                  isLast: entry.key == _timeline.length - 1,
                  onEdit: () => _editMoment(moment),
                  onDelete: () => setState(() {
                    _timeline.removeWhere((item) => item.id == moment.id);
                    _dirty = true;
                  }),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRelations() {
    final provider = context.watch<AtelierProvider>();
    final relations = provider.relationsForNode(_node!.id);
    return _CharacterSection(
      icon: Icons.hub_outlined,
      title: 'Relaciones en Mundiarium',
      child: relations.isEmpty
          ? const _CharacterEmptyState(
              icon: Icons.link_off_rounded,
              text: 'Este personaje aun no tiene relaciones.',
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: relations.map((relation) {
                final otherId = relation.sourceNodeId == _node!.id
                    ? relation.targetNodeId
                    : relation.sourceNodeId;
                final other = provider.nodeById(otherId);
                return Chip(
                  avatar: const Icon(Icons.link_rounded, size: 15),
                  label: Text(
                    '${other?.title ?? 'Elemento'} · ${relation.relationType}',
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _CharacterSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _CharacterSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _TemplateChoice extends StatelessWidget {
  final _TemplateDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateChoice({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: definition.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.13)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                definition.icon,
                color: selected ? AppColors.gold : AppColors.textSecondary,
                size: 19,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  definition.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _SelectField extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;

  const _SelectField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      dropdownColor: AppColors.cardElevated,
      items: values.entries
          .map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _CharacterMoment moment;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimelineRow({
    required this.moment,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.gold.withValues(alpha: 0.32),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (moment.date.isNotEmpty)
                              Text(
                                moment.date.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            const SizedBox(height: 3),
                            Text(
                              moment.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar momento',
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                      ),
                      IconButton(
                        tooltip: 'Eliminar momento',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 17),
                      ),
                    ],
                  ),
                  if (moment.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    FormattedManuscriptText(
                      text: moment.description,
                      fontSize: 13,
                      lineHeight: 1.55,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const _CharacterEmptyState({
    required this.icon,
    required this.text,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 28),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(buttonLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _CharacterMoment {
  final String id;
  final String date;
  final String title;
  final String description;

  const _CharacterMoment({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
  });

  static _CharacterMoment? fromDynamic(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final title = '${map['title'] ?? ''}'.trim();
    if (title.isEmpty) return null;
    return _CharacterMoment(
      id: '${map['id'] ?? title}',
      date: '${map['date'] ?? ''}',
      title: title,
      description: '${map['description'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'title': title,
        'description': description,
      };
}

class _CharacterField {
  final String key;
  final String label;
  final String hint;
  final int minimumRank;
  final int lines;
  final bool expanded;

  const _CharacterField(
    this.key,
    this.label,
    this.hint, {
    this.minimumRank = 0,
    this.lines = 1,
    this.expanded = false,
  });
}

class _CharacterFieldSection {
  final String title;
  final IconData icon;
  final int minimumRank;
  final List<_CharacterField> fields;

  const _CharacterFieldSection({
    required this.title,
    required this.icon,
    required this.fields,
    this.minimumRank = 0,
  });
}

class _TemplateDefinition {
  final String id;
  final String label;
  final String description;
  final IconData icon;

  const _TemplateDefinition(this.id, this.label, this.description, this.icon);
}

const _templateRanks = <String, int>{
  'essential': 0,
  'narrative': 1,
  'complete': 2,
};

const _templateDefinitions = <_TemplateDefinition>[
  _TemplateDefinition(
    'essential',
    'Esencial',
    'Identidad, funcion, deseo y conflicto.',
    Icons.assignment_ind_outlined,
  ),
  _TemplateDefinition(
    'narrative',
    'Narrativa',
    'Motivaciones, contradicciones y arco.',
    Icons.auto_stories_outlined,
  ),
  _TemplateDefinition(
    'complete',
    'Completa',
    'Dossier fisico, social y simbolico.',
    Icons.fact_check_outlined,
  ),
];

const _characterSections = <_CharacterFieldSection>[
  _CharacterFieldSection(
    title: 'Identidad',
    icon: Icons.fingerprint_rounded,
    fields: [
      _CharacterField('alias', 'Alias o titulo', 'Como se le conoce'),
      _CharacterField(
          'role', 'Funcion narrativa', 'Protagonista, mentor, rival'),
      _CharacterField('age', 'Edad', 'Real o aparente'),
      _CharacterField('pronouns', 'Pronombres', 'Como se refiere al personaje'),
      _CharacterField(
          'occupation', 'Ocupacion', 'Oficio, rango o responsabilidad'),
      _CharacterField(
        'species',
        'Especie o linaje',
        'Humano, estirpe, criatura',
        minimumRank: 2,
      ),
      _CharacterField(
        'origin',
        'Origen',
        'Lugar, familia o cultura',
        minimumRank: 1,
      ),
      _CharacterField(
        'affiliation',
        'Afiliacion',
        'Casa, faccion u organizacion',
        minimumRank: 2,
      ),
    ],
  ),
  _CharacterFieldSection(
    title: 'Motor dramatico',
    icon: Icons.local_fire_department_outlined,
    fields: [
      _CharacterField(
        'desire',
        'Deseo visible',
        'Que persigue de manera consciente',
        lines: 3,
      ),
      _CharacterField(
        'conflict',
        'Conflicto central',
        'Que se interpone y por que importa',
        lines: 3,
      ),
      _CharacterField(
        'need',
        'Necesidad profunda',
        'Que debe aprender, aceptar o transformar',
        minimumRank: 1,
        lines: 3,
      ),
      _CharacterField(
        'fear',
        'Miedo o perdida',
        'Que no esta dispuesto a arriesgar',
        minimumRank: 1,
        lines: 3,
      ),
      _CharacterField(
        'secret',
        'Secreto',
        'Informacion que altera la lectura del personaje',
        minimumRank: 1,
        lines: 3,
        expanded: true,
      ),
    ],
  ),
  _CharacterFieldSection(
    title: 'Psicologia y voz',
    icon: Icons.psychology_alt_outlined,
    minimumRank: 1,
    fields: [
      _CharacterField(
        'personality',
        'Rasgos dominantes',
        'Temperamento y patrones de conducta',
        minimumRank: 1,
        lines: 3,
      ),
      _CharacterField(
        'contradiction',
        'Contradiccion',
        'La tension que evita una personalidad plana',
        minimumRank: 1,
        lines: 3,
      ),
      _CharacterField(
        'strengths',
        'Fortalezas',
        'Recursos internos y capacidades',
        minimumRank: 1,
        lines: 3,
      ),
      _CharacterField(
        'flaws',
        'Debilidades',
        'Limites, sesgos y conductas destructivas',
        minimumRank: 1,
        lines: 3,
      ),
      _CharacterField(
        'voice',
        'Voz y forma de hablar',
        'Ritmo, vocabulario, silencios y gestos',
        minimumRank: 1,
        lines: 4,
        expanded: true,
      ),
    ],
  ),
  _CharacterFieldSection(
    title: 'Arco narrativo',
    icon: Icons.change_circle_outlined,
    minimumRank: 1,
    fields: [
      _CharacterField(
        'arc_start',
        'Estado inicial',
        'Creencia, equilibrio y herida al comenzar',
        minimumRank: 1,
        lines: 4,
      ),
      _CharacterField(
        'arc_turn',
        'Punto de quiebre',
        'Decision o revelacion que impide volver atras',
        minimumRank: 1,
        lines: 4,
      ),
      _CharacterField(
        'arc_end',
        'Estado final',
        'Que cambia, que conserva y que pierde',
        minimumRank: 1,
        lines: 4,
        expanded: true,
      ),
    ],
  ),
  _CharacterFieldSection(
    title: 'Presencia y mundo',
    icon: Icons.visibility_outlined,
    minimumRank: 2,
    fields: [
      _CharacterField(
        'appearance',
        'Apariencia distintiva',
        'Silueta, rostro, vestuario y marcas',
        minimumRank: 2,
        lines: 4,
      ),
      _CharacterField(
        'habits',
        'Habitos y gestos',
        'Conductas observables y rituales',
        minimumRank: 2,
        lines: 4,
      ),
      _CharacterField(
        'skills',
        'Habilidades y limites',
        'Que puede hacer y a que costo',
        minimumRank: 2,
        lines: 4,
      ),
      _CharacterField(
        'beliefs',
        'Creencias y valores',
        'Principios, prejuicios y lealtades',
        minimumRank: 2,
        lines: 4,
      ),
      _CharacterField(
        'symbols',
        'Simbolos y motivos',
        'Colores, objetos, imagenes o temas asociados',
        minimumRank: 2,
        lines: 4,
        expanded: true,
      ),
    ],
  ),
];
