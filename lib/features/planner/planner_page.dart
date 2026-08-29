import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/atelier_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/planner_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_crow_animations.dart';
import '../../shared/widgets/corvus_empty_state.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';
import '../../shared/widgets/corvus_surface.dart';

enum _TaskFilter { today, upcoming, all }

class PlannerPage extends StatefulWidget {
  final AtelierPlannerWorkspace? initialWorkspace;

  const PlannerPage({super.key, this.initialWorkspace});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  final _service = PlannerService();
  AtelierPlannerWorkspace? _workspace;
  _TaskFilter _filter = _TaskFilter.today;
  bool _loading = true;
  bool _mutating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWorkspace;
    if (initial != null) {
      _workspace = initial;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final profileId = context.read<AuthProvider>().profile?.id;
    if (profileId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workspace = await _service.load(profileId);
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos abrir tu calendario creativo.';
      });
    }
  }

  Future<void> _openTaskEditor([AtelierPlannerEntry? entry]) async {
    final workspace = _workspace;
    final profileId = context.read<AuthProvider>().profile?.id;
    if (workspace == null || profileId == null || workspace.projects.isEmpty) {
      return;
    }
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (_) => _TaskEditorDialog(
        projects: workspace.projects,
        initial: entry,
      ),
    );
    if (draft == null || !mounted) return;
    await _runMutation(() async {
      if (entry == null) {
        await _service.createTask(
          profileId: profileId,
          projectId: draft.projectId,
          title: draft.title,
          notes: draft.notes,
          scheduledFor: draft.date,
          priority: draft.priority,
        );
      } else {
        await _service.updateTask(
          entry: entry,
          title: draft.title,
          notes: draft.notes,
          scheduledFor: draft.date,
          priority: draft.priority,
        );
      }
    });
  }

  Future<void> _openJournalEditor([AtelierPlannerEntry? entry]) async {
    final workspace = _workspace;
    final profileId = context.read<AuthProvider>().profile?.id;
    if (workspace == null || profileId == null || workspace.projects.isEmpty) {
      return;
    }
    final draft = await showDialog<_JournalDraft>(
      context: context,
      builder: (_) => _JournalEditorDialog(
        projects: workspace.projects,
        initial: entry,
      ),
    );
    if (draft == null || !mounted) return;
    await _runMutation(() async {
      if (entry == null) {
        await _service.createJournal(
          profileId: profileId,
          projectId: draft.projectId,
          title: draft.title,
          body: draft.body,
          journalDate: draft.date,
          mood: draft.mood,
        );
      } else {
        await _service.updateJournal(
          entry: entry,
          title: draft.title,
          body: draft.body,
          journalDate: draft.date,
          mood: draft.mood,
        );
      }
    });
  }

  Future<void> _toggleTask(AtelierPlannerEntry entry, bool value) {
    return _runMutation(
      () => _service.setTaskCompleted(entry, completed: value),
    );
  }

  Future<void> _deleteEntry(AtelierPlannerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.isTask ? 'Eliminar tarea' : 'Eliminar entrada'),
        content: const Text('Esta accion no se puede deshacer.'),
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
    if (confirmed != true || !mounted) return;
    await _runMutation(() => _service.deleteEntry(entry));
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible guardar el cambio.')),
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  List<AtelierPlannerEntry> _visibleTasks() {
    final tasks = _workspace?.tasks ?? const <AtelierPlannerEntry>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_filter) {
      _TaskFilter.today => tasks
          .where(
            (entry) =>
                !entry.isCompleted &&
                (entry.isScheduledOn(today) || entry.isOverdueAt(now)),
          )
          .toList(),
      _TaskFilter.upcoming => tasks.where((entry) {
          final date = entry.scheduledFor;
          if (entry.isCompleted || date == null) return false;
          return DateTime(date.year, date.month, date.day).isAfter(today);
        }).toList(),
      _TaskFilter.all => tasks,
    };
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width < 640 ? 16.0 : 40.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CorvusPage(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PlannerHeader(onRefresh: _load, busy: _mutating),
              const Divider(height: 1, color: AppColors.border),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CorvusCrowLoader(label: 'Ordenando tu estudio...'),
      );
    }
    if (_error != null) {
      return CorvusEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Planificador no disponible',
        subtitle: _error!,
        actionText: 'Reintentar',
        onAction: _load,
      );
    }
    final workspace = _workspace;
    if (workspace == null) return const SizedBox.shrink();
    if (workspace.projects.isEmpty) {
      return CorvusEmptyState(
        icon: Icons.account_tree_outlined,
        title: 'Crea un proyecto primero',
        subtitle:
            'El calendario y el diario conservan cada registro dentro de su proyecto.',
        actionText: 'Abrir Atelier',
        onAction: () => context.go('/atelier'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: TabBar(
              tabs: [
                Tab(
                    icon: Icon(Icons.calendar_today_outlined),
                    text: 'Calendario'),
                Tab(icon: Icon(Icons.history_edu_outlined), text: 'Diario'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCalendar(workspace),
                _buildJournal(workspace),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(AtelierPlannerWorkspace workspace) {
    final tasks = _visibleTasks();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 56),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_TaskFilter>(
                  segments: const [
                    ButtonSegment(
                      value: _TaskFilter.today,
                      icon: Icon(Icons.today_outlined, size: 17),
                      label: Text('Hoy'),
                    ),
                    ButtonSegment(
                      value: _TaskFilter.upcoming,
                      icon: Icon(Icons.upcoming_outlined, size: 17),
                      label: Text('Proximas'),
                    ),
                    ButtonSegment(
                      value: _TaskFilter.all,
                      icon: Icon(Icons.list_alt_outlined, size: 17),
                      label: Text('Todas'),
                    ),
                  ],
                  selected: {_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() => _filter = selection.first);
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _mutating ? null : () => _openTaskEditor(),
                tooltip: 'Nueva tarea',
                icon: const Icon(Icons.add_task_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (tasks.isEmpty)
            _PlannerInlineEmpty(
              icon: Icons.event_available_outlined,
              title: _filter == _TaskFilter.today
                  ? 'El dia esta despejado'
                  : 'No hay tareas en esta vista',
              actionLabel: 'Crear tarea',
              onAction: () => _openTaskEditor(),
            )
          else
            ...tasks.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskTile(
                  entry: entry,
                  disabled: _mutating,
                  onChanged: (value) => _toggleTask(entry, value),
                  onEdit: () => _openTaskEditor(entry),
                  onDelete: () => _deleteEntry(entry),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJournal(AtelierPlannerWorkspace workspace) {
    final entries = workspace.journals;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 56),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diario del artista',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Memoria privada del proceso creativo.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: _mutating ? null : () => _openJournalEditor(),
                tooltip: 'Nueva entrada',
                icon: const Icon(Icons.note_add_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            _PlannerInlineEmpty(
              icon: Icons.history_edu_outlined,
              title: 'Tu primera nota de proceso empieza aqui',
              actionLabel: 'Escribir entrada',
              onAction: () => _openJournalEditor(),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _JournalTile(
                  entry: entry,
                  disabled: _mutating,
                  onEdit: () => _openJournalEditor(entry),
                  onDelete: () => _deleteEntry(entry),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlannerHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool busy;

  const _PlannerHeader({required this.onRefresh, required this.busy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 16),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RITMO CREATIVO',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Calendario y diario',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onRefresh,
            tooltip: 'Actualizar',
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final AtelierPlannerEntry entry;
  final bool disabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.entry,
    required this.disabled,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = entry.scheduledFor;
    final overdue = entry.isOverdueAt(DateTime.now());
    final priorityColor = switch (entry.priority) {
      'high' => AppColors.primaryLight,
      'low' => AppColors.textMuted,
      _ => AppColors.gold,
    };
    return CorvusSurface(
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: entry.isCompleted,
            onChanged: disabled ? null : (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.node.title,
                    style: TextStyle(
                      color: entry.isCompleted
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      decoration:
                          entry.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (entry.node.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      entry.node.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 9,
                    runSpacing: 5,
                    children: [
                      _InlineFact(
                        icon: Icons.calendar_today_outlined,
                        label: date == null ? 'Sin fecha' : _dateLabel(date),
                        color: overdue ? AppColors.errorLight : null,
                      ),
                      _InlineFact(
                        icon: Icons.account_tree_outlined,
                        label: entry.projectTitle,
                      ),
                      _InlineFact(
                        icon: Icons.flag_outlined,
                        label: _priorityLabel(entry.priority),
                        color: priorityColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _EntryMenu(
            disabled: disabled,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  final AtelierPlannerEntry entry;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _JournalTile({
    required this.entry,
    required this.disabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CorvusSurface(
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              children: [
                Text(
                  '${entry.journalDate.day}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _monthLabel(entry.journalDate.month).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.secondaryLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.node.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.node.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 9,
                  runSpacing: 5,
                  children: [
                    _InlineFact(
                      icon: Icons.account_tree_outlined,
                      label: entry.projectTitle,
                    ),
                    _InlineFact(
                      icon: _moodIcon(entry.mood),
                      label: _moodLabel(entry.mood),
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _EntryMenu(
            disabled: disabled,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _InlineFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InlineFact({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color ?? AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EntryMenu extends StatelessWidget {
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryMenu({
    required this.disabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !disabled,
      tooltip: 'Acciones',
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Eliminar'),
          ),
        ),
      ],
    );
  }
}

class _PlannerInlineEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _PlannerInlineEmpty({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 34),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _TaskDraft {
  final String projectId;
  final String title;
  final String notes;
  final DateTime date;
  final String priority;

  const _TaskDraft({
    required this.projectId,
    required this.title,
    required this.notes,
    required this.date,
    required this.priority,
  });
}

class _TaskEditorDialog extends StatefulWidget {
  final List<AtelierProject> projects;
  final AtelierPlannerEntry? initial;

  const _TaskEditorDialog({required this.projects, this.initial});

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late String _projectId;
  late DateTime _date;
  late String _priority;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.node.title ?? '');
    _notes = TextEditingController(text: initial?.node.body ?? '');
    _projectId = initial?.node.projectId ?? widget.projects.first.id;
    _date = initial?.scheduledFor ?? DateTime.now();
    _priority = initial?.priority ?? 'normal';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _TaskDraft(
        projectId: _projectId,
        title: title,
        notes: _notes.text.trim(),
        date: _date,
        priority: _priority,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Editar tarea' : 'Nueva tarea'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                decoration: const InputDecoration(
                  labelText: 'Proyecto',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: widget.projects
                    .map(
                      (project) => DropdownMenuItem(
                        value: project.id,
                        child: Text(project.title),
                      ),
                    )
                    .toList(),
                onChanged: editing
                    ? null
                    : (value) => setState(() => _projectId = value!),
              ),
              const SizedBox(height: 13),
              CorvusMarkdownFieldPreview(
                controller: _title,
                child: TextField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Tarea',
                    prefixIcon: Icon(Icons.task_alt_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              CorvusMarkdownFieldPreview(
                controller: _notes,
                child: TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
              ),
              const SizedBox(height: 13),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Fecha'),
                subtitle: Text(_dateLabel(_date)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'low', label: Text('Baja')),
                  ButtonSegment(value: 'normal', label: Text('Normal')),
                  ButtonSegment(value: 'high', label: Text('Alta')),
                ],
                selected: {_priority},
                showSelectedIcon: false,
                onSelectionChanged: (values) {
                  setState(() => _priority = values.first);
                },
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
          onPressed: _submit,
          child: Text(editing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

class _JournalDraft {
  final String projectId;
  final String title;
  final String body;
  final DateTime date;
  final String mood;

  const _JournalDraft({
    required this.projectId,
    required this.title,
    required this.body,
    required this.date,
    required this.mood,
  });
}

class _JournalEditorDialog extends StatefulWidget {
  final List<AtelierProject> projects;
  final AtelierPlannerEntry? initial;

  const _JournalEditorDialog({required this.projects, this.initial});

  @override
  State<_JournalEditorDialog> createState() => _JournalEditorDialogState();
}

class _JournalEditorDialogState extends State<_JournalEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _projectId;
  late DateTime _date;
  late String _mood;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.node.title ?? '');
    _body = TextEditingController(text: initial?.node.body ?? '');
    _projectId = initial?.node.projectId ?? widget.projects.first.id;
    _date = initial?.journalDate ?? DateTime.now();
    _mood = initial?.mood ?? 'neutral';
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    final title = _title.text.trim();
    Navigator.pop(
      context,
      _JournalDraft(
        projectId: _projectId,
        title: title.isEmpty ? _dateLabel(_date) : title,
        body: body,
        date: _date,
        mood: _mood,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Editar entrada' : 'Nueva entrada'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                decoration: const InputDecoration(
                  labelText: 'Proyecto',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: widget.projects
                    .map(
                      (project) => DropdownMenuItem(
                        value: project.id,
                        child: Text(project.title),
                      ),
                    )
                    .toList(),
                onChanged: editing
                    ? null
                    : (value) => setState(() => _projectId = value!),
              ),
              const SizedBox(height: 13),
              CorvusMarkdownFieldPreview(
                controller: _title,
                child: TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Titulo',
                    hintText: 'Opcional',
                  ),
                ),
              ),
              const SizedBox(height: 13),
              CorvusMarkdownFieldPreview(
                controller: _body,
                child: TextField(
                  controller: _body,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Registro del proceso',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Fecha del registro'),
                subtitle: Text(_dateLabel(_date)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _mood,
                decoration: const InputDecoration(
                  labelText: 'Pulso del dia',
                  prefixIcon: Icon(Icons.psychology_alt_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'flow', child: Text('En flujo')),
                  DropdownMenuItem(value: 'focused', child: Text('Enfocado')),
                  DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
                  DropdownMenuItem(value: 'blocked', child: Text('Bloqueado')),
                  DropdownMenuItem(value: 'restless', child: Text('Inquieto')),
                ],
                onChanged: (value) => setState(() => _mood = value!),
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
          onPressed: _submit,
          child: Text(editing ? 'Guardar' : 'Registrar'),
        ),
      ],
    );
  }
}

String _dateLabel(DateTime date) {
  return '${date.day} ${_monthLabel(date.month)} ${date.year}';
}

String _monthLabel(int month) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return months[(month - 1).clamp(0, 11)];
}

String _priorityLabel(String priority) {
  return switch (priority) {
    'high' => 'Prioridad alta',
    'low' => 'Prioridad baja',
    _ => 'Prioridad normal',
  };
}

String _moodLabel(String mood) {
  return switch (mood) {
    'flow' => 'En flujo',
    'focused' => 'Enfocado',
    'blocked' => 'Bloqueado',
    'restless' => 'Inquieto',
    _ => 'Neutral',
  };
}

IconData _moodIcon(String mood) {
  return switch (mood) {
    'flow' => Icons.waves_rounded,
    'focused' => Icons.center_focus_strong_outlined,
    'blocked' => Icons.block_outlined,
    'restless' => Icons.bolt_outlined,
    _ => Icons.remove_circle_outline,
  };
}
