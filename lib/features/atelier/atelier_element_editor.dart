import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/router/navigation_coordinator.dart';
import '../../models/atelier_models.dart';
import '../../providers/atelier_provider.dart';
import '../../shared/widgets/corvus_tag_input.dart';
import 'atelier_rich_text_editor.dart';

const _statusLabels = <String, String>{
  'idea': 'Idea',
  'draft': 'Borrador',
  'active': 'Activo',
  'review': 'En revisión',
  'done': 'Terminado',
  'archived': 'Archivado',
};

const _canonLabels = <String, String>{
  'canon': 'Canon',
  'semi-canon': 'Semi-canon',
  'no-canon': 'No canon',
  'draft': 'Borrador',
  'alternate': 'Alternativo',
  'retcon': 'Retcon',
};

/// Editor a pantalla completa para un elemento del Atelier (capítulo, escena,
/// fragmento...). Reemplaza el diálogo compacto de "Nuevo elemento".
class AtelierElementEditor extends StatefulWidget {
  final String profileId;
  final String projectId;
  final String initialKind;
  final Map<String, String> kindLabels;
  final AtelierNode? node;

  const AtelierElementEditor({
    super.key,
    required this.profileId,
    required this.projectId,
    required this.initialKind,
    required this.kindLabels,
    this.node,
  });

  @override
  State<AtelierElementEditor> createState() => _AtelierElementEditorState();
}

class _AtelierElementEditorState extends State<AtelierElementEditor> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.node?.title ?? '');
  late final AtelierRichTextController _bodyController =
      AtelierRichTextController(text: widget.node?.body ?? '');
  final FocusNode _bodyFocusNode = FocusNode();
  final ScrollController _bodyScrollController = ScrollController();

  AtelierNode? _node;
  late String _kind = widget.node?.kind ?? widget.initialKind;
  late String _status = widget.node?.status ?? 'draft';
  late String _canonStatus = widget.node?.canonStatus ?? 'canon';
  late List<String> _tags = List.of(widget.node?.tags ?? const []);
  late String _internalDate = (widget.node?.metadata['date'] as String?) ?? '';
  late String _purpose = (widget.node?.metadata['purpose'] as String?) ?? '';
  late TextAlign _textAlign =
      atelierTextAlign(widget.node?.metadata['text_alignment']);

  bool _isDirty = false;
  bool _isSaving = false;
  bool _focusMode = false;
  DateTime? _lastSaved;

  String get _kindLabel => widget.kindLabels[_kind] ?? _kind;

  int get _wordCount {
    final text = _bodyController.text.trim();
    if (text.isEmpty) return 0;
    return RegExp(r'\S+').allMatches(text).length;
  }

  int get _characterCount => _bodyController.text.length;

  int get _readingMinutes {
    if (_wordCount == 0) return 0;
    return (_wordCount / 220).ceil();
  }

  Color get _statusColor {
    switch (_status) {
      case 'done':
        return AppColors.successLight;
      case 'review':
        return AppColors.gold;
      case 'active':
        return AppColors.primaryLight;
      case 'archived':
        return AppColors.textMuted;
      default:
        return AppColors.secondaryLight;
    }
  }

  String get _saveStateLabel {
    if (_isSaving) return 'guardando...';
    if (_isDirty) return 'sin guardar';
    if (_lastSaved != null) return 'guardado';
    return _statusLabels[_status] ?? _status;
  }

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _titleController.addListener(_markDirty);
    _bodyController.addListener(_handleBodyChanged);
    AppNavigationCoordinator.instance.registerExitGuard(
      this,
      _confirmNavigationExit,
    );
  }

  void _markDirty() {
    if (!_isDirty && mounted) setState(() => _isDirty = true);
    // El contador de palabras se refresca con el mismo setState del listener.
    if (mounted) setState(() {});
  }

  void _handleBodyChanged() {
    _markDirty();
    if (_focusMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerCaret());
    }
  }

  void _centerCaret() {
    if (!_bodyScrollController.hasClients) return;
    final selection = _bodyController.selection;
    final caret = selection.isValid ? selection.extentOffset : 0;
    final beforeCaret = _bodyController.text.substring(
      0,
      caret.clamp(0, _bodyController.text.length).toInt(),
    );
    final hardLines = RegExp(r'\n').allMatches(beforeCaret).length;
    final wrappedLines = beforeCaret.length ~/ 72;
    final target = ((hardLines + wrappedLines) * 31.0) - 250;
    _bodyScrollController.animateTo(
      target
          .clamp(0, _bodyScrollController.position.maxScrollExtent)
          .toDouble(),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    AppNavigationCoordinator.instance.unregisterExitGuard(this);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  // ─── Persistencia ────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildMetadata() => {
        if (_node != null) ..._node!.metadata,
        if (_internalDate.trim().isNotEmpty)
          'date': _internalDate.trim()
        else if (_node?.metadata.containsKey('date') ?? false)
          'date': null,
        if (_purpose.trim().isNotEmpty)
          'purpose': _purpose.trim()
        else if (_node?.metadata.containsKey('purpose') ?? false)
          'purpose': null,
        'text_alignment': atelierAlignmentName(_textAlign),
      }..removeWhere((_, value) => value == null);

  Future<bool> _save({String? statusOverride, bool silent = false}) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);

    final title = _titleController.text.trim().isEmpty
        ? 'Sin título'
        : _titleController.text.trim();
    final status = statusOverride ?? _status;
    final provider = context.read<AtelierProvider>();
    var publicationLinked = false;
    var publicationSynced = false;

    try {
      if (_node == null) {
        final created = await provider.createNode(
          profileId: widget.profileId,
          projectId: widget.projectId,
          kind: _kind,
          title: title,
          body: _bodyController.text,
          status: status,
          canonStatus: _canonStatus,
          tags: _tags,
          metadata: _buildMetadata(),
        );
        _node = created;
        final workId =
            (provider.activeProject?.metadata['publication_work_id'] as String?)
                    ?.trim() ??
                '';
        publicationLinked = workId.isNotEmpty;
        if (publicationLinked) {
          try {
            publicationSynced = await provider.syncPublication() != null;
          } catch (_) {
            publicationSynced = false;
          }
        }
      } else {
        final result = await provider.updateNode(
          _node!.copyWith(
            kind: _kind,
            title: title,
            body: _bodyController.text,
            status: status,
            canonStatus: _canonStatus,
            tags: _tags,
            metadata: _buildMetadata(),
          ),
        );
        publicationLinked = result.publicationLinked;
        publicationSynced = result.publicationSynced;
        _node = provider.nodeById(_node!.id) ?? _node;
      }

      if (!mounted) return false;
      setState(() {
        _status = status;
        _isDirty = false;
        _isSaving = false;
        _lastSaved = DateTime.now();
      });
      if (!silent) {
        _showMessage(
          !publicationLinked
              ? 'Guardado'
              : publicationSynced
                  ? 'Guardado y publicación actualizada'
                  : 'Guardado. No se pudo actualizar la publicación',
        );
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _isSaving = false);
      _showMessage('No se pudo guardar: $error');
      return false;
    }
  }

  Future<void> _publish() async {
    final ok = await _save(statusOverride: 'done', silent: true);
    if (ok && mounted) {
      _showMessage(
        '$_kindLabel sellado como terminado. Se incluirá al preparar la publicación.',
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Eliminar $_kindLabel?',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        content: Text(
          _node == null
              ? 'Se descartará este elemento sin guardar.'
              : 'Se eliminará "${_node!.title}" y sus relaciones. Esta acción no se puede deshacer.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 13,
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (_node != null) {
      await context
          .read<AtelierProvider>()
          .deleteNode(widget.profileId, _node!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleClose() async {
    final canClose = await _confirmEditorExit(confirmWhenClean: true);
    if (!canClose || !mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmNavigationExit() =>
      _confirmEditorExit(confirmWhenClean: true);

  Future<bool> _confirmEditorExit({bool confirmWhenClean = false}) async {
    if (!_isDirty) {
      if (!confirmWhenClean) return true;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '¿Deseas salir del editor?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'No hay cambios pendientes. Volverás al espacio de trabajo de Atelier.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Salir',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
      return confirmed == true;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Deseas salir sin guardar?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        content: Text(
          'Tienes cambios sin guardar.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: Text('Descartar cambios',
                style: TextStyle(
                    color: Colors.redAccent.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('stay'),
            child: Text('Seguir editando',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Guardar y salir',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (!mounted) return false;
    switch (choice) {
      case 'save':
        return _save(silent: true);
      case 'discard':
        setState(() => _isDirty = false);
        return true;
      default:
        return false;
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.card,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _format(VoidCallback action) {
    action();
    _bodyFocusNode.requestFocus();
  }

  void _insertWikilink() {
    _format(() => _bodyController.toggleInline('[[', ']]'));
  }

  void _insertSceneBreak() {
    _format(_bodyController.insertSeparator);
  }

  void _insertHeading(int level) {
    _format(() => _bodyController.toggleBlock(level == 1 ? '# ' : '## '));
  }

  void _insertBold() {
    _format(() => _bodyController.toggleInline('**'));
  }

  void _insertItalic() {
    _format(() => _bodyController.toggleInline('*'));
  }

  void _insertQuote() {
    _format(() => _bodyController.toggleBlock('> '));
  }

  void _insertListItem() {
    _format(() => _bodyController.toggleBlock('• '));
  }

  void _setAlignment(TextAlign alignment) {
    if (_textAlign == alignment) return;
    setState(() {
      _textAlign = alignment;
      _isDirty = true;
    });
    _bodyFocusNode.requestFocus();
  }

  void _toggleFocusMode() {
    final next = !_focusMode;
    _bodyController.focusMode = next;
    setState(() => _focusMode = next);
    _bodyFocusNode.requestFocus();
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerCaret());
    }
  }

  Future<void> _changeStatus(String status) async {
    setState(() {
      _status = status;
      _isDirty = true;
    });
    await _save(silent: true);
  }

  // ─── Detalles del elemento ───────────────────────────────────────────────────

  Future<void> _openDetails() async {
    var kind = _kind;
    var status = _status;
    var canonStatus = _canonStatus;
    var tags = List.of(_tags);
    final dateController = TextEditingController(text: _internalDate);
    final purposeController = TextEditingController(text: _purpose);

    final kindValues = Map<String, String>.from(widget.kindLabels);
    kindValues.putIfAbsent(kind, () => kind);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detalles del elemento',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  _EditorDropdown(
                    label: 'Tipo',
                    value: kind,
                    labels: kindValues,
                    onChanged: (v) => setDialogState(() => kind = v),
                  ),
                  const SizedBox(height: 14),
                  CorvusTagInput(
                    label: 'Tags',
                    hint: 'trama, giro, personaje…',
                    values: tags,
                    onChanged: (v) => setDialogState(() => tags = v),
                  ),
                  const SizedBox(height: 14),
                  _EditorTextField(
                    controller: dateController,
                    label: 'Fecha interna (YYYY-MM-DD)',
                  ),
                  const SizedBox(height: 14),
                  _EditorTextField(
                    controller: purposeController,
                    label: 'Propósito narrativo',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  _EditorDropdown(
                    label: 'Estado',
                    value: status,
                    labels: _statusLabels,
                    onChanged: (v) => setDialogState(() => status = v),
                  ),
                  const SizedBox(height: 14),
                  _EditorDropdown(
                    label: 'Canon',
                    value: canonStatus,
                    labels: _canonLabels,
                    onChanged: (v) => setDialogState(() => canonStatus = v),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancelar',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Aplicar',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _kind = kind;
        _status = status;
        _canonStatus = canonStatus;
        _tags = tags;
        _internalDate = dateController.text.trim();
        _purpose = purposeController.text.trim();
        _isDirty = true;
      });
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(compact),
              Expanded(child: _buildEditor()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool compact) {
    return Container(
      height: compact ? 72 : 78,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isSaving ? null : _handleClose,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 17, color: AppColors.textSecondary),
            tooltip: 'Volver',
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.24),
                ),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 240,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleController.text.trim().isEmpty
                        ? 'Sin título'
                        : _titleController.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Atelier / $_kindLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.34),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          _ActionButton(
            icon: Icons.save_outlined,
            label: 'Guardar',
            compact: compact,
            onTap: _isSaving ? null : () => _save(),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.approval_rounded,
            label: _status == 'done' ? 'Terminado' : 'Terminar',
            compact: compact,
            filled: true,
            onTap: _isSaving ? null : _publish,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            color: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            icon: Icon(Icons.more_vert_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.55)),
            onSelected: (value) {
              switch (value) {
                case 'details':
                  _openDetails();
                case 'draft':
                  setState(() {
                    _status = 'draft';
                    _isDirty = true;
                  });
                  _save(silent: true);
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'details',
                child: _MenuRow(
                    icon: Icons.tune_rounded, label: 'Detalles del elemento'),
              ),
              if (_status == 'done')
                const PopupMenuItem(
                  value: 'draft',
                  child: _MenuRow(
                      icon: Icons.edit_note_rounded,
                      label: 'Volver a borrador'),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: _MenuRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Eliminar $_kindLabel',
                  danger: true,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!compact) ...[
            _EditorMetric(
              icon: Icons.article_outlined,
              value: '$_wordCount',
              label: _wordCount == 1 ? 'palabra' : 'palabras',
            ),
            const SizedBox(width: 8),
            _EditorMetric(
              icon: Icons.schedule_rounded,
              value: '$_readingMinutes',
              label: _readingMinutes == 1 ? 'min' : 'mins',
            ),
            const SizedBox(width: 10),
          ],
          _SaveStateChip(
            label: _saveStateLabel,
            dirty: _isDirty,
            saving: _isSaving,
            color: _statusColor,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  // ─── Editor ──────────────────────────────────────────────────────────────────

  Widget _buildEditor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1120;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryMuted.withValues(alpha: 0.16),
                AppColors.background,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 34 : 18,
              wide ? 26 : 18,
              wide ? 34 : 18,
              0,
            ),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 280,
                        child: SingleChildScrollView(
                          child: _buildInspectorPanel(),
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(child: _buildWritingCanvas(compact: false)),
                    ],
                  )
                : Column(
                    children: [
                      _buildCompactInspectorMenu(),
                      const SizedBox(height: 12),
                      Expanded(child: _buildWritingCanvas(compact: true)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildWritingCanvas({required bool compact}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          children: [
            _buildInlineTools(compact),
            const SizedBox(height: 12),
            Expanded(child: _buildBodySurface(compact: compact)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentHeader(bool compact) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(compact ? 24 : 52, 28, compact ? 24 : 52, 18),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _DocumentChip(
                icon: Icons.category_outlined,
                label: _kindLabel.toUpperCase(),
                color: AppColors.primary,
              ),
              _DocumentChip(
                icon: Icons.adjust_rounded,
                label: _statusLabels[_status] ?? _status,
                color: _statusColor,
              ),
              _DocumentChip(
                icon: Icons.account_tree_outlined,
                label: _canonLabels[_canonStatus] ?? _canonStatus,
                color: AppColors.secondaryLight,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            textAlign: TextAlign.center,
            maxLines: 2,
            minLines: 1,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: compact ? 28 : 36,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
            decoration: InputDecoration(
              hintText: 'Título del ${_kindLabel.toLowerCase()}',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.18),
                fontSize: compact ? 26 : 34,
                fontWeight: FontWeight.w900,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
          Container(
            width: 52,
            height: 3,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineTools(bool compact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ToolButton(
            icon: Icons.title_rounded,
            label: 'H1',
            compact: compact,
            onTap: () => _insertHeading(1),
          ),
          _ToolButton(
            icon: Icons.short_text_rounded,
            label: 'H2',
            compact: compact,
            onTap: () => _insertHeading(2),
          ),
          _ToolButton(
            icon: Icons.format_bold_rounded,
            label: 'Negrita',
            compact: compact,
            onTap: _insertBold,
          ),
          _ToolButton(
            icon: Icons.format_italic_rounded,
            label: 'Cursiva',
            compact: compact,
            onTap: _insertItalic,
          ),
          _ToolButton(
            icon: Icons.format_quote_rounded,
            label: 'Cita',
            compact: compact,
            onTap: _insertQuote,
          ),
          _ToolButton(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Lista',
            compact: compact,
            onTap: _insertListItem,
          ),
          _ToolButton(
            icon: Icons.tune_rounded,
            label: 'Detalles',
            compact: compact,
            onTap: _openDetails,
          ),
          _ToolButton(
            icon: Icons.link_rounded,
            label: 'Wikilink',
            compact: compact,
            onTap: _insertWikilink,
          ),
          _ToolButton(
            icon: Icons.horizontal_rule_rounded,
            label: 'Corte',
            compact: compact,
            onTap: _insertSceneBreak,
          ),
          _ToolButton(
            icon: Icons.format_align_left_rounded,
            label: 'Izquierda',
            tooltip: 'Alinear a la izquierda',
            compact: compact,
            active: _textAlign == TextAlign.left,
            onTap: () => _setAlignment(TextAlign.left),
          ),
          _ToolButton(
            icon: Icons.format_align_center_rounded,
            label: 'Centrar',
            tooltip: 'Centrar',
            compact: compact,
            active: _textAlign == TextAlign.center,
            onTap: () => _setAlignment(TextAlign.center),
          ),
          _ToolButton(
            icon: Icons.format_align_right_rounded,
            label: 'Derecha',
            tooltip: 'Alinear a la derecha',
            compact: compact,
            active: _textAlign == TextAlign.right,
            onTap: () => _setAlignment(TextAlign.right),
          ),
          _ToolButton(
            icon: Icons.format_align_justify_rounded,
            label: 'Justificar',
            tooltip: 'Justificar',
            compact: compact,
            active: _textAlign == TextAlign.justify,
            onTap: () => _setAlignment(TextAlign.justify),
          ),
          _ToolButton(
            icon: Icons.center_focus_strong_rounded,
            label: 'Concentración',
            tooltip: 'Modo concentración',
            compact: compact,
            active: _focusMode,
            onTap: _toggleFocusMode,
          ),
        ],
      ),
    );
  }

  Widget _buildBodySurface({required bool compact}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF120D17),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildDocumentHeader(compact),
          if (_focusMode)
            Container(
              margin: EdgeInsets.symmetric(horizontal: compact ? 24 : 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.center_focus_strong_rounded,
                      size: 14, color: AppColors.primaryLight),
                  SizedBox(width: 7),
                  Text(
                    'MODO CONCENTRACIÓN',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildLiveEditorPane(compact: compact)),
        ],
      ),
    );
  }

  Widget _buildLiveEditorPane({required bool compact}) {
    return TextField(
      key: const ValueKey('atelier-element-rich-editor'),
      controller: _bodyController,
      focusNode: _bodyFocusNode,
      scrollController: _bodyScrollController,
      maxLines: null,
      expands: true,
      textAlign: _textAlign,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: compact ? 16 : 17,
        height: 1.95,
      ),
      decoration: InputDecoration(
        hintText:
            'Comienza a escribir. El formato aparecerá directamente en la página.',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.24),
          fontSize: compact ? 15 : 16,
          height: 1.9,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(
          compact ? 24 : 64,
          22,
          compact ? 24 : 64,
          72,
        ),
      ),
    );
  }

  Widget _buildInspectorPanel() {
    return Column(
      children: [
        _EditorSidebarSection(
          icon: Icons.menu_book_outlined,
          title: 'Dossier',
          child: Column(
            children: [
              _InspectorRow(label: 'Tipo', value: _kindLabel),
              _InspectorRow(
                label: 'Estado',
                value: _statusLabels[_status] ?? _status,
                color: _statusColor,
              ),
              _InspectorRow(
                label: 'Canon',
                value: _canonLabels[_canonStatus] ?? _canonStatus,
              ),
              if (_internalDate.trim().isNotEmpty)
                _InspectorRow(label: 'Fecha interna', value: _internalDate),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _StatCapsule(label: 'Palabras', value: '$_wordCount'),
                  _StatCapsule(label: 'Caracteres', value: '$_characterCount'),
                  _StatCapsule(label: 'Lectura', value: '${_readingMinutes}m'),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _tags
                      .map((tag) => _TagPill(label: tag))
                      .toList(growable: false),
                ),
              ],
              if (_purpose.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _purpose,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _PanelButton(
                icon: Icons.tune_rounded,
                label: 'Editar detalles',
                onTap: _openDetails,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _EditorSidebarSection(
          icon: Icons.account_tree_outlined,
          title: 'Flujo',
          child: Column(
            children: [
              _StatusOption(
                label: 'Borrador',
                selected: _status == 'draft',
                onTap: () => _changeStatus('draft'),
              ),
              _StatusOption(
                label: 'Activo',
                selected: _status == 'active',
                onTap: () => _changeStatus('active'),
              ),
              _StatusOption(
                label: 'En revisión',
                selected: _status == 'review',
                onTap: () => _changeStatus('review'),
              ),
              _StatusOption(
                label: 'Terminado',
                selected: _status == 'done',
                onTap: () => _changeStatus('done'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInspectorMenu() => _buildInspectorPanel();
}

// ─── Componentes ──────────────────────────────────────────────────────────────

class _EditorSidebarSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _EditorSidebarSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: AppColors.card.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey<String>('atelier-editor-$title'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: AppColors.primaryLight),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            title == 'Dossier'
                ? 'Detalles y estadísticas'
                : 'Estado de la escritura',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.34),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconColor: AppColors.primaryLight,
          collapsedIconColor: Colors.white.withValues(alpha: 0.42),
          children: [child],
        ),
      ),
    );
  }
}

class _EditorMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _EditorMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.38), size: 15),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveStateChip extends StatelessWidget {
  final String label;
  final bool dirty;
  final bool saving;
  final Color color;

  const _SaveStateChip({
    required this.label,
    required this.dirty,
    required this.saving,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = dirty ? Colors.orangeAccent : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saving)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Icon(
              dirty ? Icons.edit_note_rounded : Icons.check_rounded,
              size: 14,
              color: effectiveColor.withValues(alpha: 0.88),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DocumentChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.88)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.88),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final bool compact;
  final bool active;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color:
                      active ? AppColors.primaryLight : AppColors.textSecondary,
                ),
                if (!compact) ...[
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? AppColors.primaryLight
                          : Colors.white.withValues(alpha: 0.62),
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
    );
  }
}

class _InspectorRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InspectorRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = color ?? AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.36),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor.withValues(alpha: 0.90),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCapsule extends StatelessWidget {
  final String label;
  final String value;

  const _StatCapsule({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.36),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;

  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primaryLight.withValues(alpha: 0.82),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PanelButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.34),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryLight
                      : Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool compact;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.compact,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = filled
        ? Colors.white
        : Colors.white.withValues(alpha: disabled ? 0.25 : 0.62);

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 8),
          decoration: BoxDecoration(
            color: filled
                ? (disabled
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.primary)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _MenuRow(
      {required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Colors.redAccent.withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.75);
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EditorDropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  const _EditorDropdown({
    required this.label,
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: labels.containsKey(value) ? value : labels.keys.first,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.40)),
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              items: labels.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
    return field;
  }
}

class _EditorTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _EditorTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              isDense: true,
            ),
          ),
        ),
      ],
    );
    return field;
  }
}
