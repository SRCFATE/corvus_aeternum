import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../../core/theme/app_colors.dart';
import '../../core/browser_exit_guard.dart';
import '../../core/router/navigation_coordinator.dart';
import '../../models/atelier_models.dart';
import '../../models/atelier_comment.dart';
import '../../providers/atelier_provider.dart';
import '../../services/atelier_service.dart';
import '../../services/atelier_comment_service.dart';
import '../../shared/widgets/corvus_tag_input.dart';
import '../../shared/widgets/corvus_save_status.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';
import 'atelier_draft_store.dart';
import 'atelier_document_outline.dart';
import 'atelier_reference_repair.dart';
import 'atelier_reference_repair_sheet.dart';
import 'atelier_manuscript_navigator.dart';
import 'atelier_history_sheet.dart';
import 'atelier_publication_dialog.dart';
import 'atelier_comments_sheet.dart';
import 'atelier_text_diff.dart';
import 'atelier_writing_progress.dart';
import 'atelier_quill_document.dart';

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

class _AtelierElementEditorState extends State<AtelierElementEditor>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.node?.title ?? '');
  late final quill.QuillController _bodyController =
      createAtelierQuillController(
    body: widget.node?.body ?? '',
    metadata: widget.node?.metadata ?? const {},
  );
  final FocusNode _bodyFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _editorScrollController = ScrollController();
  late StreamSubscription<quill.DocChange> _bodyChangesSubscription;
  final _quillKey = GlobalKey<quill.EditorState>();
  final _manuscriptKey = GlobalKey();
  final _focusBand = ValueNotifier<Rect?>(null);
  final _searchRects = ValueNotifier<List<Rect>>([]);
  String _searchQuery = '';
  int _searchOffset = 0;

  AtelierNode? _node;
  String _creationId = const Uuid().v4();
  Map<String, dynamic>? _creationSnapshot;
  late String _kind = widget.node?.kind ?? widget.initialKind;
  late String _status = widget.node?.status ?? 'draft';
  late String _canonStatus = widget.node?.canonStatus ?? 'canon';
  late List<String> _tags = List.of(widget.node?.tags ?? const []);
  late String _internalDate = (widget.node?.metadata['date'] as String?) ?? '';
  late String _purpose = (widget.node?.metadata['purpose'] as String?) ?? '';
  bool _isDirty = false;
  bool _isSaving = false;
  bool _focusMode = false;
  String _focusUnit = 'paragraph';
  bool _serif = true;
  DateTime? _lastSaved;
  final _draftStore = AtelierDraftStore();
  late String _draftKey = _draftStore.key(
    widget.profileId,
    widget.projectId,
    widget.node?.id ?? 'new-${widget.initialKind}-$_creationId',
  );
  late final BrowserExitGuard _browserExitGuard;
  Timer? _autosave;
  Timer? _retry;
  int _revision = 0;
  bool _recovering = true;
  bool _restoring = false;
  bool _saveFailed = false;
  bool _conflict = false;
  bool _localFailed = false;
  bool _publishing = false;
  bool _canEdit = true;
  bool _exitDialogOpen = false;
  bool _commandOpen = false;
  double _fontSize = 18;
  double _lineHeight = 1.8;
  double _panelWidth = 360;
  bool _panelPinned = false;
  bool _panelOpen = false;
  int _panelTab = 0;
  Future<bool>? _pendingSave;

  bool get _publicationLinked =>
      (context
              .read<AtelierProvider>()
              .activeProject
              ?.metadata['publication_work_id'] as String?)
          ?.isNotEmpty ==
      true;

  String get _kindLabel => widget.kindLabels[_kind] ?? _kind;

  int get _wordCount {
    final text =
        _bodyController.document.toPlainText().replaceAll('\uFFFC', '').trim();
    if (text.isEmpty) return 0;
    return RegExp(r'\S+').allMatches(text).length;
  }

  int get _characterCount =>
      _bodyController.document.toPlainText().trimRight().length;

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

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    if (widget.node != null && widget.node!.profileId != widget.profileId) {
      _canEdit = false;
      _bodyController.readOnly = true;
      unawaited(_loadCapabilities());
    }
    _lastSaved = widget.node?.updatedAt;
    _browserExitGuard = BrowserExitGuard(() => _isDirty || _isSaving);
    WidgetsBinding.instance.addObserver(this);
    _titleController.addListener(_markDirty);
    _bodyController.addListener(_handleSelectionChanged);
    _listenToDocument();
    unawaited(_loadAppearance());
    AppNavigationCoordinator.instance.registerExitGuard(
      this,
      _confirmNavigationExit,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverDraft());
  }

  Future<void> _loadCapabilities() async {
    try {
      final capabilities =
          await AtelierCommentService().capabilities(widget.projectId);
      if (!mounted) return;
      setState(() {
        _canEdit = capabilities.contains('project.write');
        _bodyController.readOnly = !_canEdit;
      });
    } catch (_) {/* Un permiso sin verificar permanece en solo lectura. */}
  }

  void _listenToDocument() {
    _bodyChangesSubscription = _bodyController.changes.listen((_) {
      _markDirty();
      _scheduleCaretCentering();
      if (!_restoring && !_commandOpen) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _checkTypedCommand());
      }
    });
  }

  Future<void> _loadAppearance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _fontSize = (prefs.getDouble('atelier.font.${widget.profileId}') ?? 18)
            .clamp(14, 28);
        _lineHeight =
            (prefs.getDouble('atelier.leading.${widget.profileId}') ?? 1.8)
                .clamp(1.3, 2.4);
        _focusMode =
            prefs.getBool('atelier.focus.${widget.profileId}') ?? false;
        _focusUnit = prefs.getString('atelier.focusUnit.${widget.profileId}') ??
            'paragraph';
        _serif = prefs.getBool('atelier.serif.${widget.profileId}') ?? true;
        _panelWidth =
            (prefs.getDouble('atelier.panel.${widget.profileId}') ?? 360)
                .clamp(300, 560);
        _panelPinned =
            prefs.getBool('atelier.panelPinned.${widget.profileId}') ?? false;
        _panelOpen =
            prefs.getBool('atelier.panelOpen.${widget.profileId}') ?? false;
        _panelTab = (prefs.getInt('atelier.panelTab.${widget.profileId}') ?? 0)
            .clamp(0, 1);
      });
    } catch (_) {/* La apariencia no debe impedir abrir el manuscrito. */}
  }

  Future<void> _rememberAppearance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('atelier.font.${widget.profileId}', _fontSize);
      await prefs.setDouble('atelier.leading.${widget.profileId}', _lineHeight);
      await prefs.setBool('atelier.focus.${widget.profileId}', _focusMode);
      await prefs.setString(
          'atelier.focusUnit.${widget.profileId}', _focusUnit);
      await prefs.setBool('atelier.serif.${widget.profileId}', _serif);
      await prefs.setDouble('atelier.panel.${widget.profileId}', _panelWidth);
      await prefs.setBool(
          'atelier.panelPinned.${widget.profileId}', _panelPinned);
      await prefs.setBool('atelier.panelOpen.${widget.profileId}', _panelOpen);
      await prefs.setInt('atelier.panelTab.${widget.profileId}', _panelTab);
    } catch (_) {/* Se mantiene la preferencia durante esta sesión. */}
  }

  void _markDirty() {
    if (!mounted || _restoring) return;
    _revision++;
    setState(() => _isDirty = true);
    unawaited(_persistDraft());
    _scheduleSave();
  }

  void _scheduleSave() {
    _autosave?.cancel();
    if (_conflict) return;
    _autosave = Timer(const Duration(seconds: 2), () {
      if (mounted && !_exitDialogOpen && !_recovering) _save(silent: true);
    });
  }

  Map<String, dynamic> _draftSnapshot() => {
        'title': _titleController.text,
        'body': atelierQuillToMarkdown(_bodyController),
        'metadata': _buildMetadata(),
        'kind': _kind,
        'status': _status,
        'canon_status': _canonStatus,
        'tags': List<String>.of(_tags),
        'node_id': _node?.id,
        'creation_id': _creationId,
        'creation_snapshot': _creationSnapshot,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'base_updated_at': _node?.updatedAt.toUtc().toIso8601String(),
      };

  Future<void> _persistDraft() async {
    try {
      await _draftStore.write(_draftKey, _draftSnapshot());
      if (mounted && _localFailed) setState(() => _localFailed = false);
    } catch (_) {
      if (mounted) setState(() => _localFailed = true);
    }
  }

  Future<void> _recoverDraft() async {
    try {
      var draft = await _draftStore.read(_draftKey);
      var selectedNewBackup = false;
      if (widget.node == null) {
        final pending = await _draftStore.pendingNew(
            widget.profileId, widget.projectId, widget.initialKind);
        if (!mounted) return;
        if (pending.isNotEmpty) {
          final selected = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                    title: const Text('Borradores pendientes'),
                    content: SizedBox(
                        width: 440,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 360),
                            child: ListView(shrinkWrap: true, children: [
                              const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                      'Recupera un borrador o empieza otro. Los respaldos se conservan hasta que confirmes su guardado.')),
                              for (final backup in pending)
                                ListTile(
                                    leading:
                                        const Icon(Icons.restore_page_outlined),
                                    title: Text(
                                        (backup.draft['title'] as String?)
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? backup.draft['title'] as String
                                            : 'Elemento sin título'),
                                    subtitle: Text(DateTime.tryParse(
                                                backup.draft['saved_at']
                                                        as String? ??
                                                    '')
                                            ?.toLocal()
                                            .toString()
                                            .split('.')
                                            .first ??
                                        'Respaldo local'),
                                    onTap: () =>
                                        Navigator.pop(ctx, backup.key)),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Empezar otro elemento'))
                    ],
                  ));
          if (!mounted) return;
          if (selected != null) {
            _draftKey = selected;
            draft =
                pending.firstWhere((backup) => backup.key == selected).draft;
            selectedNewBackup = true;
          }
        }
      }
      if (!mounted) return;
      if (draft != null) {
        final restore = selectedNewBackup
            ? true
            : await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('Recuperar borrador'),
                  content: const Text(
                      'Hay cambios conservados en este dispositivo. Puedes recuperarlos antes de seguir escribiendo. La versión guardada en el proyecto se conserva hasta que guardes.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Usar versión del proyecto')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Recuperar cambios')),
                  ],
                ),
              );
        if (!mounted) return;
        if (restore == true) {
          _restoring = true;
          final metadata = Map<String, dynamic>.from(draft['metadata'] as Map);
          final recovered = createAtelierQuillController(
              body: draft['body'] as String, metadata: metadata);
          unawaited(_bodyChangesSubscription.cancel());
          _bodyController.document = recovered.document;
          _listenToDocument();
          _titleController.text = draft['title'] as String;
          _kind = draft['kind'] as String;
          _status = draft['status'] as String;
          _canonStatus = draft['canon_status'] as String;
          _tags = List<String>.from(draft['tags'] as List);
          _internalDate = metadata['date'] as String? ?? '';
          _purpose = metadata['purpose'] as String? ?? '';
          // Si un alta había llegado al servidor antes del cierre, reutilizarla.
          final recoveredId = draft['node_id'] as String?;
          _node ??= context.read<AtelierProvider>().nodeById(recoveredId);
          _creationId = draft['creation_id'] as String? ?? _creationId;
          _creationSnapshot = draft['creation_snapshot'] is Map
              ? Map<String, dynamic>.from(draft['creation_snapshot'] as Map)
              : null;
          final base =
              DateTime.tryParse(draft['base_updated_at'] as String? ?? '');
          _conflict = base != null &&
              _node != null &&
              !base.isAtSameMomentAs(_node!.updatedAt);
          _restoring = false;
          _revision++;
          _isDirty = true;
          // Requiere guardar conscientemente: otra sesión pudo avanzar.
        } else if (restore == false) {
          await _draftStore.remove(_draftKey);
        }
      }
    } catch (_) {
      if (mounted) {
        _localFailed = true;
        _showMessage(
            'No se pudo abrir el respaldo local. Se conserva para intentar recuperarlo de nuevo.');
      }
    } finally {
      _restoring = false;
      if (mounted) setState(() => _recovering = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDirty) unawaited(_persistDraft());
    if (state == AppLifecycleState.resumed && _isDirty && !_recovering) {
      unawaited(_save(silent: true));
    }
  }

  void _handleSelectionChanged() {
    if (mounted) setState(() {});
    _scheduleCaretCentering();
  }

  void _scheduleCaretCentering() {
    if (_focusMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerCaret();
        _updateFocusBand();
      });
    }
  }

  void _updateFocusBand() {
    if (!mounted || !_focusMode || !_bodyController.selection.isValid) return;
    final render = _quillKey.currentState?.renderEditor;
    final surface = _manuscriptKey.currentContext?.findRenderObject();
    if (render == null || surface is! RenderBox) return;
    final text = _bodyController.document.toPlainText();
    final caret =
        _bodyController.selection.extentOffset.clamp(0, text.length - 1);
    var start = caret;
    var end = caret;
    if (_focusUnit != 'line') {
      final separator =
          _focusUnit == 'sentence' ? RegExp(r'[.!?\n]') : RegExp(r'\n');
      while (start > 0 && !separator.hasMatch(text[start - 1])) {
        start--;
      }
      while (end < text.length - 1 && !separator.hasMatch(text[end])) {
        end++;
      }
    }
    final first = render.getLocalRectForCaret(TextPosition(offset: start));
    final last = render.getLocalRectForCaret(TextPosition(offset: end));
    final top = surface.globalToLocal(render.localToGlobal(first.topLeft)).dy;
    final bottom =
        surface.globalToLocal(render.localToGlobal(last.bottomRight)).dy;
    _focusBand.value =
        Rect.fromLTRB(0, top - 8, surface.size.width, bottom + 8);
  }

  void _centerCaret() {
    if (!mounted ||
        !_pageScrollController.hasClients ||
        !_bodyFocusNode.hasFocus) {
      return;
    }
    final render = _quillKey.currentState?.renderEditor;
    if (render == null || !render.attached) return;
    final selection = _bodyController.selection;
    if (!selection.isValid) return;
    final rect = render
        .getLocalRectForCaret(TextPosition(offset: selection.extentOffset));
    final caretY = render.localToGlobal(rect.center).dy;
    final viewport = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final delta = caretY - viewport * .55;
    if (delta.abs() < 60) return;
    final target = _pageScrollController.offset + delta;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageScrollController.jumpTo(target
          .clamp(0, _pageScrollController.position.maxScrollExtent)
          .toDouble());
      return;
    }
    _pageScrollController.animateTo(
      target
          .clamp(0, _pageScrollController.position.maxScrollExtent)
          .toDouble(),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _retry?.cancel();
    _browserExitGuard.dispose();
    _focusBand.dispose();
    _searchRects.dispose();
    WidgetsBinding.instance.removeObserver(this);
    AppNavigationCoordinator.instance.unregisterExitGuard(this);
    _bodyChangesSubscription.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _pageScrollController.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  // ─── Persistencia ────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildMetadata() => recordWritingProgress(
      {
        if (_node != null) ..._node!.metadata,
        if (_internalDate.trim().isNotEmpty)
          'date': _internalDate.trim()
        else if (_node?.metadata.containsKey('date') ?? false)
          'date': null,
        if (_purpose.trim().isNotEmpty)
          'purpose': _purpose.trim()
        else if (_node?.metadata.containsKey('purpose') ?? false)
          'purpose': null,
        'text_alignment': atelierPrimaryAlignment(_bodyController),
        atelierRichTextDeltaKey: atelierQuillDeltaJson(_bodyController),
      }..removeWhere((_, value) => value == null),
      before: _node?.wordCount ?? 0,
      after: _wordCount,
      now: DateTime.now());

  Future<bool> _save({String? statusOverride, bool silent = false}) async {
    if (!_canEdit || _conflict) return false;
    _autosave?.cancel();
    _retry?.cancel();
    if (_pendingSave != null) {
      final ok = await _pendingSave!;
      if (!ok || !mounted) return false;
      if (!_isDirty && statusOverride == null) return true;
      return _save(statusOverride: statusOverride, silent: silent);
    }
    if (!mounted || _recovering) return false;
    final operation =
        _saveSnapshot(statusOverride: statusOverride, silent: silent);
    _pendingSave = operation;
    try {
      return await operation;
    } finally {
      if (identical(_pendingSave, operation)) _pendingSave = null;
    }
  }

  Future<bool> _saveSnapshot(
      {String? statusOverride, bool silent = false}) async {
    if (statusOverride != null) {
      _status = statusOverride;
      _revision++;
      _isDirty = true;
    }
    setState(() => _isSaving = true);
    final revision = _revision;
    final snapshot = _draftSnapshot();
    final title = _titleController.text.trim().isEmpty
        ? 'Sin título'
        : _titleController.text.trim();
    final status = statusOverride ?? _status;
    final provider = context.read<AtelierProvider>();

    try {
      if (_node == null) {
        _creationSnapshot ??= {
          'kind': snapshot['kind'],
          'title': title,
          'body': snapshot['body'],
          'status': status,
          'canon_status': snapshot['canon_status'],
          'tags': snapshot['tags'],
          'metadata': snapshot['metadata'],
        };
      }
      await _persistDraft();
      if (_node == null) {
        // Retry the same first write, then save any text typed since that write.
        // Keeping this request in the local draft also survives a browser close.
        final creation = _creationSnapshot!;
        final created = await provider.createNode(
          nodeId: _creationId,
          profileId: widget.profileId,
          projectId: widget.projectId,
          kind: creation['kind'] as String,
          title: creation['title'] as String,
          body: creation['body'] as String,
          status: creation['status'] as String,
          canonStatus: creation['canon_status'] as String,
          tags: List<String>.from(creation['tags'] as List),
          metadata: creation['metadata'] as Map<String, dynamic>,
        );
        if (created == null) throw StateError('No se confirmó el guardado');
        _node = created;
        final latest = {
          'kind': snapshot['kind'],
          'title': title,
          'body': snapshot['body'],
          'status': status,
          'canon_status': snapshot['canon_status'],
          'tags': snapshot['tags'],
          'metadata': snapshot['metadata'],
        };
        if (!const DeepCollectionEquality().equals(creation, latest)) {
          _revision++;
        }
        _creationSnapshot = null;
      } else {
        await provider.updateNode(
          _node!.copyWith(
            kind: snapshot['kind'] as String,
            title: title,
            body: snapshot['body'] as String,
            status: status,
            canonStatus: snapshot['canon_status'] as String,
            tags: List<String>.from(snapshot['tags'] as List),
            metadata: snapshot['metadata'] as Map<String, dynamic>,
          ),
        );
        _node = provider.nodeById(_node!.id) ?? _node;
      }

      if (!mounted) return false;
      setState(() {
        _isDirty = revision != _revision;
        _isSaving = false;
        _saveFailed = false;
        _conflict = false;
        _lastSaved = DateTime.now();
      });
      if (!_isDirty) {
        try {
          await _draftStore.remove(_draftKey);
        } catch (_) {}
      } else {
        await _persistDraft();
        _scheduleSave();
      }
      if (!silent) {
        if (mounted) _showMessage('Guardado en el proyecto');
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      _conflict = error is AtelierConflictException;
      if (error is AtelierConflictException && error.remote != null) {
        _node = error.remote;
        _creationSnapshot = null;
        await _persistDraft();
        if (!mounted) return false;
      }
      setState(() {
        _isSaving = false;
        _saveFailed = true;
        _isDirty = true;
      });
      if (!_conflict) {
        _retry = Timer(const Duration(seconds: 20), () {
          if (mounted && _isDirty && !_exitDialogOpen) _save(silent: true);
        });
      }
      if (!silent) {
        _showMessage(
            'No se pudo sincronizar. Conservamos tus cambios en este dispositivo si el respaldo local está disponible. Puedes reintentar.');
      }
      return false;
    }
  }

  Future<void> _publish() async {
    if (_publishing) return;
    if (!_publicationLinked) {
      if (await _save(statusOverride: 'done', silent: true) && mounted) {
        _showMessage('$_kindLabel listo. Revisa y publica desde el proyecto.');
      }
      return;
    }
    if (!await _save(silent: true) || !mounted || _isDirty) return;
    final confirmed = await confirmAtelierPublication(
        context, context.read<AtelierProvider>(),
        action: 'Actualizar publicación');
    if (confirmed != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      if (!await _save(silent: true) || !mounted) return;
      final result = await context.read<AtelierProvider>().syncPublication();
      if (result == null) throw StateError('Sin publicación vinculada');
      if (mounted) {
        _showMessage(result.isPublished
            ? 'Publicación actualizada'
            : 'Borrador de publicación actualizado. Completa la publicación desde el proyecto.');
      }
    } on AtelierPublicationException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
            'El proyecto está guardado. No se pudo confirmar la actualización de la publicación; puedes reintentar.');
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
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
                fontWeight: FontWeight.w700)),
        content: Text(
          _node == null
              ? 'Se descartará este elemento sin guardar.'
              : 'Se moverá "${_node!.title}" a la papelera del proyecto. Podrás recuperarlo con sus relaciones.',
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
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || !_canEdit) return;
    _exitDialogOpen = true;
    _autosave?.cancel();
    _retry?.cancel();
    try {
      if (_pendingSave != null) await _pendingSave;
      _autosave?.cancel();
      _retry?.cancel();
      if (!mounted) return;
      if (_node != null) {
        if (_isDirty && !await _save(silent: true)) {
          if (mounted) {
            _showMessage(
                'No se movió a la papelera: primero guarda o resuelve los cambios pendientes.');
          }
          return;
        }
        if (!mounted) return;
        await context
            .read<AtelierProvider>()
            .deleteNode(widget.profileId, _node!);
      }
      await _draftStore.remove(_draftKey);
      if (!mounted) return;
      setState(() => _isDirty = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        _showMessage(
            'No se pudo mover a la papelera. El contenido se conserva.');
      }
    } finally {
      _exitDialogOpen = false;
    }
  }

  Future<void> _resolveConflict() async {
    if (_node == null || !_canEdit) return;
    final provider = context.read<AtelierProvider>();
    try {
      await provider.load(widget.profileId, projectId: widget.projectId);
      if (!mounted) return;
      if (provider.error != null) throw StateError('No se pudo cargar');
      final remote = provider.nodeById(_node!.id);
      if (remote == null) {
        _showMessage(
            'El elemento no está disponible. Tu borrador local se conserva.');
        return;
      }
      final mine = atelierQuillToMarkdown(_bodyController);
      final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Comparar cambios de otra sesión'),
                content: SizedBox(
                    width: 650,
                    height: MediaQuery.sizeOf(ctx).height * .55,
                    child: ListView(children: [
                      const Text(
                          'Compara la copia guardada con tu borrador. Conservar tu borrador reemplazará el contenido guardado; conservar la otra copia descartará los cambios de este dispositivo.'),
                      Text(
                          'Guardado: ${remote.title} · Tu borrador: ${_titleController.text}'),
                      EditorialTextDiff(before: remote.body, after: mine),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Seguir comparando después')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, 'remote'),
                      child: const Text('Usar copia guardada')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'local'),
                      child: const Text('Conservar mi borrador')),
                ],
              ));
      if (!mounted || choice == null) return;
      if (choice == 'remote') {
        _adoptNode(remote);
        await _draftStore.remove(_draftKey);
      } else {
        await provider.createVersionSnapshot(
            profileId: widget.profileId,
            projectId: widget.projectId,
            label: 'Antes de resolver cambios simultáneos',
            description:
                'Copia conservada antes de aceptar el borrador local.');
        if (!mounted) return;
        setState(() {
          _node = remote;
          _conflict = false;
        });
        await _save();
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
            'No se pudo completar la comparación. Conservamos el borrador local.');
      }
    }
  }

  void _adoptNode(AtelierNode node) {
    _restoring = true;
    unawaited(_bodyChangesSubscription.cancel());
    _bodyController.document =
        createAtelierQuillController(body: node.body, metadata: node.metadata)
            .document;
    _listenToDocument();
    _titleController.text = node.title;
    _restoring = false;
    setState(() {
      _node = node;
      _kind = node.kind;
      _status = node.status;
      _canonStatus = node.canonStatus;
      _tags = List.of(node.tags);
      _internalDate = node.metadata['date'] as String? ?? '';
      _purpose = node.metadata['purpose'] as String? ?? '';
      _lastSaved = node.updatedAt;
      _isDirty = false;
      _conflict = false;
      _saveFailed = false;
    });
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
    if (_exitDialogOpen || _recovering || _publishing) return false;
    if (_pendingSave != null) await _pendingSave;
    if (!mounted) return false;
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
              fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      return confirmed == true;
    }

    _exitDialogOpen = true;
    _autosave?.cancel();
    _retry?.cancel();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Deseas salir sin guardar?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
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
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    _exitDialogOpen = false;
    if (!mounted) return false;
    switch (choice) {
      case 'save':
        final saved = await _save(silent: true);
        return saved && !_isDirty;
      case 'discard':
        await _draftStore.remove(_draftKey);
        if (!mounted) return false;
        setState(() => _isDirty = false);
        return true;
      default:
        _scheduleSave();
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
    if (!_canEdit) return;
    action();
    _bodyFocusNode.requestFocus();
  }

  void _checkTypedCommand() {
    if (!mounted || _commandOpen || !_canEdit || _restoring || _recovering) {
      return;
    }
    final selection = _bodyController.selection;
    if (!selection.isValid || !selection.isCollapsed || selection.start < 1) {
      return;
    }
    final text = _bodyController.document.toPlainText();
    final at = selection.start - 1;
    if (at >= text.length ||
        (at > 0 && !RegExp(r'\s').hasMatch(text[at - 1]))) {
      return;
    }
    if (text[at] == '@') _insertWikilink(triggerOffset: at);
    if (text[at] == '/' && (at == 0 || text[at - 1] == '\n')) {
      _openBlockCommands(at);
    }
  }

  Future<void> _openBlockCommands(int offset) async {
    _commandOpen = true;
    final command = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
        for (final entry in {
          'h1': 'Sección principal',
          'h2': 'Subtítulo',
          'h3': 'Subtítulo menor',
          'quote': 'Cita',
          'list': 'Lista',
          'break': 'Separador de escena'
        }.entries)
          ListTile(
              title: Text(entry.value),
              onTap: () => Navigator.pop(ctx, entry.key)),
      ])),
    );
    if (mounted &&
        command != null &&
        offset < _bodyController.document.length - 1 &&
        _bodyController.document.toPlainText()[offset] == '/') {
      _bodyController.replaceText(
          offset, 1, '', TextSelection.collapsed(offset: offset));
      switch (command) {
        case 'h1':
          _insertHeading(1);
        case 'h2':
          _insertHeading(2);
        case 'h3':
          _insertHeading(3);
        case 'quote':
          _insertQuote();
        case 'list':
          _insertListItem();
        case 'break':
          _insertSceneBreak();
      }
    }
    _commandOpen = false;
  }

  Future<void> _insertWikilink({int? triggerOffset}) async {
    if (!_canEdit || _commandOpen) return;
    _commandOpen = true;
    final provider = context.read<AtelierProvider>();
    final selection = _bodyController.selection;
    var query = '';
    var creating = false;
    String? creationError;
    var newKind = 'character';
    final target = await showModalBottomSheet<AtelierNode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
        final nodes = provider.worldNodes
            .where((node) => atelierReferenceNames(node).any(
                (name) => name.toLowerCase().contains(query.toLowerCase())))
            .toList();
        return SafeArea(
            child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(ctx).bottom),
                child: SizedBox(
                    height: MediaQuery.sizeOf(ctx).height * .65,
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                              autofocus: true,
                              decoration: const InputDecoration(
                                  labelText:
                                      'Mencionar una ficha de Mundiarium'),
                              onChanged: (value) =>
                                  refresh(() => query = value))),
                      if (nodes.isEmpty && query.trim().isEmpty)
                        const ListTile(
                            title: Text(
                                'Escribe un nombre para buscar o crear una ficha.')),
                      if (query.trim().isNotEmpty &&
                          !provider.worldNodes.any((node) =>
                              node.title.toLowerCase() ==
                              query.trim().toLowerCase()))
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(children: [
                              DropdownButtonFormField<String>(
                                initialValue: newKind,
                                decoration: const InputDecoration(
                                    labelText: 'Tipo de ficha nueva'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'character',
                                      child: Text('Personaje')),
                                  DropdownMenuItem(
                                      value: 'place', child: Text('Lugar')),
                                  DropdownMenuItem(
                                      value: 'concept',
                                      child: Text('Concepto')),
                                ],
                                onChanged: creating
                                    ? null
                                    : (value) =>
                                        refresh(() => newKind = value!),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text(creating
                                    ? 'Creando ficha…'
                                    : 'Crear «${query.trim()}» y vincular'),
                                onPressed: creating
                                    ? null
                                    : () async {
                                        refresh(() {
                                          creating = true;
                                          creationError = null;
                                        });
                                        try {
                                          final created =
                                              await provider.createNode(
                                            profileId: widget.profileId,
                                            projectId: widget.projectId,
                                            kind: newKind,
                                            title: query.trim(),
                                          );
                                          if (ctx.mounted && created != null) {
                                            Navigator.pop(ctx, created);
                                          }
                                        } catch (_) {
                                          if (ctx.mounted) {
                                            refresh(() => creationError =
                                                'No se pudo crear la ficha. Inténtalo de nuevo.');
                                          }
                                        } finally {
                                          if (ctx.mounted) {
                                            refresh(() => creating = false);
                                          }
                                        }
                                      },
                              ),
                              const Text(
                                  'La ficha se crea privada. Puedes completarla en Mundiarium.'),
                              if (creationError != null)
                                Text(creationError!,
                                    style: const TextStyle(
                                        color: AppColors.errorLight)),
                            ])),
                      Expanded(
                          child: ListView.builder(
                              itemCount: nodes.length,
                              itemBuilder: (ctx, index) => ListTile(
                                  title: Text(nodes[index].title),
                                  onTap: () =>
                                      Navigator.pop(ctx, nodes[index])))),
                      if (_bodyController
                          .getSelectionStyle()
                          .attributes
                          .containsKey('link'))
                        TextButton(
                            onPressed: () {
                              _bodyController.formatSelection(
                                  const quill.LinkAttribute(null));
                              Navigator.pop(ctx);
                            },
                            child:
                                const Text('Quitar vínculo de la selección')),
                    ]))));
      }),
    );
    if (mounted && target != null) {
      final start = triggerOffset ?? (selection.isValid ? selection.start : 0);
      final length = triggerOffset != null
          ? 1
          : (selection.isValid ? selection.end - selection.start : 0);
      _bodyController.replaceText(start, length, target.title,
          TextSelection.collapsed(offset: start + target.title.length));
      _bodyController.formatText(start, target.title.length,
          quill.LinkAttribute('corvus-node:${target.id}'));
      _bodyFocusNode.requestFocus();
    }
    _commandOpen = false;
  }

  Future<void> _openReference(String url) async {
    if (!url.startsWith('corvus-node:')) {
      final uri = Uri.tryParse(url);
      if (uri != null && {'https', 'http', 'mailto'}.contains(uri.scheme)) {
        try {
          await launchUrl(uri);
        } catch (_) {
          if (mounted) _showMessage('No se pudo abrir el vínculo.');
        }
      }
      return;
    }
    final node = context
        .read<AtelierProvider>()
        .nodeById(url.substring('corvus-node:'.length));
    if (node == null) {
      _showMessage('La ficha no está disponible en este proyecto.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
          child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * .7,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text(node.title, style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 16),
                FormattedManuscriptText(text: node.body),
                const Divider(),
                const Text('Aparece en'),
                for (final source in context
                    .read<AtelierProvider>()
                    .nodes
                    .where((source) =>
                        source.body.contains('corvus-node:${node.id}')))
                  ListTile(title: Text(source.title)),
              ]))),
    );
  }

  Future<void> _repairReferences() async {
    if (!_canEdit) return;
    final provider = context.read<AtelierProvider>();
    final original = atelierQuillDeltaJson(_bodyController);
    final repairs = atelierReferenceRepairs(original, provider.worldNodes);
    if (repairs.isEmpty) {
      _showMessage(
          'No hay referencias antiguas ni nombres vinculados pendientes de actualizar.');
      return;
    }
    final choices = await showModalBottomSheet<List<AtelierReferenceChoice>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AtelierReferenceRepairSheet(repairs: repairs));
    if (!mounted || choices == null || choices.isEmpty) return;
    if (!const DeepCollectionEquality()
            .equals(original, atelierQuillDeltaJson(_bodyController)) ||
        choices.any((choice) =>
            provider.nodeById(choice.target.id)?.title !=
            choice.target.title)) {
      _showMessage(
          'El texto o una ficha cambió. Vuelve a revisar las referencias.');
      return;
    }
    choices.sort((a, b) => b.repair.offset.compareTo(a.repair.offset));
    for (final choice in choices) {
      final repair = choice.repair;
      final label = repair.replacement(choice.target);
      _bodyController.replaceText(repair.offset, repair.source.length, label,
          TextSelection.collapsed(offset: repair.offset + label.length));
      _bodyController.formatText(repair.offset, label.length,
          quill.LinkAttribute('corvus-node:${choice.target.id}'));
    }
    _bodyFocusNode.requestFocus();
    _showMessage(
        'Referencias actualizadas. Puedes deshacer los cambios desde la barra.');
  }

  void _insertSceneBreak() {
    _format(() {
      final selection = _bodyController.selection;
      final start = selection.start;
      _bodyController.replaceText(
        start,
        selection.end - start,
        const quill.BlockEmbed('divider', ''),
        TextSelection.collapsed(offset: start + 1),
      );
    });
  }

  void _insertHeading(int level) {
    _toggleAttribute(level == 1
        ? quill.Attribute.h1
        : level == 2
            ? quill.Attribute.h2
            : quill.Attribute.h3);
  }

  void _insertBold() {
    _toggleAttribute(quill.Attribute.bold);
  }

  void _insertItalic() {
    _toggleAttribute(quill.Attribute.italic);
  }

  void _insertUnderline() {
    _toggleAttribute(quill.Attribute.underline);
  }

  void _insertStrikeThrough() {
    _toggleAttribute(quill.Attribute.strikeThrough);
  }

  void _insertQuote() {
    _toggleAttribute(quill.Attribute.blockQuote);
  }

  void _insertListItem() {
    _toggleAttribute(quill.Attribute.ul);
  }

  void _setAlignment(TextAlign alignment) {
    _format(() => _bodyController.formatSelection(
          atelierAlignmentAttribute(alignment),
        ));
  }

  void _toggleAttribute(quill.Attribute<dynamic> attribute) {
    _format(() {
      final selected =
          _bodyController.getSelectionStyle().attributes[attribute.key];
      final isActive = selected?.value == attribute.value;
      _bodyController.formatSelection(
        isActive ? quill.Attribute.clone(attribute, null) : attribute,
      );
    });
  }

  bool _attributeIsActive(quill.Attribute<dynamic> attribute) {
    if (attribute.key == 'align' && _alignmentMixed) return false;
    final selected =
        _bodyController.getSelectionStyle().attributes[attribute.key];
    if (attribute == quill.Attribute.leftAlignment && selected == null) {
      return true;
    }
    return selected?.value == attribute.value;
  }

  bool get _alignmentMixed =>
      _bodyController
          .getAllSelectionStyles()
          .map((style) => style.attributes['align']?.value ?? 'left')
          .toSet()
          .length >
      1;

  void _toggleFocusMode() {
    final next = !_focusMode;
    setState(() => _focusMode = next);
    unawaited(_rememberAppearance());
    _bodyFocusNode.requestFocus();
    if (next) {
      _scheduleCaretCentering();
    }
  }

  Future<void> _changeStatus(String status) async {
    if (!_canEdit) return;
    setState(() {
      _status = status;
    });
    _markDirty();
    await _save(silent: true);
  }

  // ─── Detalles del elemento ───────────────────────────────────────────────────

  Future<void> _openDetails() async {
    if (!_canEdit) return;
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
                          fontWeight: FontWeight.w700)),
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
                            style: TextStyle(fontWeight: FontWeight.w700)),
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
      });
      _markDirty();
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;

    return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              _save(),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
              _save(),
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_focusMode) {
              _toggleFocusMode();
            } else if (_panelPinned && _panelOpen) {
              setState(() => _panelOpen = false);
              unawaited(_rememberAppearance());
            }
          },
        },
        child: PopScope(
          canPop: !_isDirty && !_isSaving && !_publishing,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleClose();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(compact),
                  if (!_recovering) _buildInlineTools(true),
                  if (!_focusMode && !_recovering)
                    _buildSecondaryTools(compact),
                  if (!_focusMode && _searchQuery.isNotEmpty)
                    _buildSearchNavigation(),
                  if (_localFailed)
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                            'El respaldo local no está disponible. Mantén esta página abierta hasta guardar.',
                            style: TextStyle(color: AppColors.errorLight))),
                  if (_conflict)
                    ListTile(
                        title: const Text(
                            'Este elemento cambió en otra sesión. Tu borrador se conserva.'),
                        trailing: TextButton(
                            onPressed: _resolveConflict,
                            child: const Text('Comparar'))),
                  Expanded(
                      child: _recovering
                          ? const Center(child: Text('Abriendo borrador…'))
                          : Row(children: [
                              Expanded(child: _buildEditor()),
                              if (_panelPinned &&
                                  _panelOpen &&
                                  !_focusMode &&
                                  MediaQuery.sizeOf(context).width >= 1100)
                                SizedBox(
                                    width: _panelWidth,
                                    child: _buildPinnedInspector()),
                            ])),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildSecondaryTools(bool compact) {
    final tools = <(String, IconData, VoidCallback)>[
      ('Dossier', Icons.menu_book_outlined, () => _openInspector(0)),
      ('Flujo', Icons.account_tree_outlined, () => _openInspector(1)),
      ('Índice y búsqueda', Icons.toc, _openNavigator),
      ('Apariencia', Icons.text_fields, _openAppearance),
      ('Historial', Icons.history, _openHistory),
      ('Revisar referencias', Icons.link, _repairReferences),
      ('Comentarios', Icons.comment_outlined, _openComments),
    ];
    return Wrap(spacing: compact ? 0 : 8, children: [
      for (final tool in tools)
        if (compact)
          IconButton(tooltip: tool.$1, onPressed: tool.$3, icon: Icon(tool.$2))
        else
          TextButton.icon(
              onPressed: tool.$3, icon: Icon(tool.$2), label: Text(tool.$1)),
    ]);
  }

  Widget _buildTopBar(bool compact) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Atelier / ${context.read<AtelierProvider>().activeProject?.title ?? _kindLabel}',
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
            onTap: _isSaving || _recovering ? null : () => _save(),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.approval_rounded,
            label: _publicationLinked
                ? 'Actualizar publicación'
                : 'Terminar ${_kindLabel.toLowerCase()}',
            compact: compact,
            filled: true,
            onTap: _isSaving || _publishing || _recovering ? null : _publish,
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
                  _changeStatus('draft');
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
          CorvusSaveStatus(
            state: _isSaving
                ? CorvusSaveState.saving
                : _saveFailed
                    ? CorvusSaveState.error
                    : _isDirty || _lastSaved == null
                        ? CorvusSaveState.unsaved
                        : CorvusSaveState.saved,
            savedAt: _lastSaved,
            onRetry: _conflict ? _resolveConflict : () => _save(),
          ),
          if (_publicationLinked)
            Text(
                _isDirty ||
                        !context.watch<AtelierProvider>().publicationIsCurrent
                    ? 'Pendiente de publicar'
                    : context
                                .read<AtelierProvider>()
                                .activeProject
                                ?.metadata['publication_is_public'] ==
                            true
                        ? 'Publicado'
                        : 'Borrador de publicación actualizado',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  // ─── Editor ──────────────────────────────────────────────────────────────────

  Widget _buildEditor() {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1120;
          return Scrollbar(
            controller: _pageScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _pageScrollController,
              primary: false,
              padding: EdgeInsets.fromLTRB(
                wide ? 34 : 18,
                wide ? 26 : 18,
                wide ? 34 : 18,
                72,
              ),
              child: _buildWritingCanvas(compact: !wide),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWritingCanvas({required bool compact}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBodySurface(compact: compact),
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
        mainAxisSize: MainAxisSize.min,
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
            readOnly: !_canEdit,
            textAlign: TextAlign.center,
            maxLines: 2,
            minLines: 1,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: compact ? 28 : 36,
              fontWeight: FontWeight.w700,
              height: 1.08,
            ),
            decoration: InputDecoration(
              hintText: 'Título del ${_kindLabel.toLowerCase()}',
              filled: false,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.18),
                fontSize: compact ? 26 : 34,
                fontWeight: FontWeight.w700,
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
    if (_focusMode) {
      return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
                tooltip: 'Deshacer',
                onPressed: () => _format(_bodyController.undo),
                icon: const Icon(Icons.undo)),
            IconButton(
                tooltip: 'Rehacer',
                onPressed: () => _format(_bodyController.redo),
                icon: const Icon(Icons.redo)),
            PopupMenuButton<String>(
                tooltip: 'Unidad de concentración',
                initialValue: _focusUnit,
                onSelected: (value) {
                  setState(() => _focusUnit = value);
                  _rememberAppearance();
                  _scheduleCaretCentering();
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'line', child: Text('Enfocar línea')),
                      PopupMenuItem(
                          value: 'sentence', child: Text('Enfocar oración')),
                      PopupMenuItem(
                          value: 'paragraph', child: Text('Enfocar párrafo'))
                    ],
                child: const Padding(
                    padding: EdgeInsets.all(12), child: Text('Enfoque ▾'))),
            TextButton.icon(
                onPressed: _toggleFocusMode,
                icon: const Icon(Icons.fullscreen_exit),
                label: const Text('Salir de concentración')),
          ]);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ToolButton(
                  icon: Icons.undo,
                  label: 'Deshacer',
                  compact: true,
                  onTap: () => _format(_bodyController.undo)),
              _ToolButton(
                  icon: Icons.redo,
                  label: 'Rehacer',
                  compact: true,
                  onTap: () => _format(_bodyController.redo)),
              _ToolButton(
                icon: Icons.title_rounded,
                label: 'H1',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.h1),
                onTap: () => _insertHeading(1),
              ),
              _ToolButton(
                icon: Icons.short_text_rounded,
                label: 'H2',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.h2),
                onTap: () => _insertHeading(2),
              ),
              _ToolButton(
                icon: Icons.format_bold_rounded,
                label: 'Negrita',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.bold),
                onTap: _insertBold,
              ),
              _ToolButton(
                  icon: Icons.short_text,
                  label: 'H3',
                  compact: true,
                  active: _attributeIsActive(quill.Attribute.h3),
                  onTap: () => _insertHeading(3)),
              _ToolButton(
                icon: Icons.format_italic_rounded,
                label: 'Cursiva',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.italic),
                onTap: _insertItalic,
              ),
              _ToolButton(
                icon: Icons.format_underlined_rounded,
                label: 'Subrayado',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.underline),
                onTap: _insertUnderline,
              ),
              _ToolButton(
                icon: Icons.format_strikethrough_rounded,
                label: 'Tachado',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.strikeThrough),
                onTap: _insertStrikeThrough,
              ),
              _ToolButton(
                icon: Icons.format_quote_rounded,
                label: 'Cita',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.blockQuote),
                onTap: _insertQuote,
              ),
              _ToolButton(
                icon: Icons.format_list_bulleted_rounded,
                label: 'Lista',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.ul),
                onTap: _insertListItem,
              ),
              _ToolButton(
                icon: Icons.link_rounded,
                label: 'Referencia',
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
                active: _attributeIsActive(quill.Attribute.leftAlignment),
                onTap: () => _setAlignment(TextAlign.left),
              ),
              if (_alignmentMixed)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Alineación mixta')),
              _ToolButton(
                icon: Icons.format_align_center_rounded,
                label: 'Centrar',
                tooltip: 'Centrar',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.centerAlignment),
                onTap: () => _setAlignment(TextAlign.center),
              ),
              _ToolButton(
                icon: Icons.format_align_right_rounded,
                label: 'Derecha',
                tooltip: 'Alinear a la derecha',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.rightAlignment),
                onTap: () => _setAlignment(TextAlign.right),
              ),
              _ToolButton(
                icon: Icons.format_align_justify_rounded,
                label: 'Justificar',
                tooltip: 'Justificar',
                compact: compact,
                active: _attributeIsActive(quill.Attribute.justifyAlignment),
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
          )),
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
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          Stack(key: _manuscriptKey, children: [
            _buildLiveEditorPane(compact: compact),
            if (_searchQuery.isNotEmpty)
              Positioned.fill(
                  child: IgnorePointer(
                      child: ValueListenableBuilder<List<Rect>>(
                valueListenable: _searchRects,
                builder: (_, rectangles, child) =>
                    CustomPaint(painter: _SearchHighlight(rectangles)),
              ))),
            if (_focusMode)
              Positioned.fill(
                  child: IgnorePointer(
                      child: ValueListenableBuilder<Rect?>(
                valueListenable: _focusBand,
                builder: (_, band, child) =>
                    CustomPaint(painter: _FocusShade(band)),
              ))),
          ]),
        ],
      ),
    );
  }

  Widget _buildLiveEditorPane({required bool compact}) {
    return quill.QuillEditor(
      key: const ValueKey('atelier-element-rich-editor'),
      controller: _bodyController,
      focusNode: _bodyFocusNode,
      scrollController: _editorScrollController,
      config: quill.QuillEditorConfig(
        editorKey: _quillKey,
        embedBuilders: const [AtelierSceneBreakBuilder()],
        // Quill consume Escape antes de sus atajos personalizados. Este único
        // adaptador conserva el cierre de paneles; está cubierto por regresión.
        // ignore: experimental_member_use
        onKeyPressed: (event, _) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (_focusMode) {
              _toggleFocusMode();
              return KeyEventResult.handled;
            }
            if (_panelPinned && _panelOpen) {
              setState(() => _panelOpen = false);
              unawaited(_rememberAppearance());
              return KeyEventResult.handled;
            }
          }
          return null;
        },
        contextMenuBuilder: (context, state) =>
            AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            ...state.contextMenuButtonItems,
            if (_canEdit && !_bodyController.selection.isCollapsed) ...[
              ContextMenuButtonItem(
                  label: 'Negrita',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _insertBold();
                  }),
              ContextMenuButtonItem(
                  label: 'Cursiva',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _insertItalic();
                  }),
              ContextMenuButtonItem(
                  label: 'Subrayado',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _insertUnderline();
                  }),
              ContextMenuButtonItem(
                  label: 'Comentar',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _openComments();
                  }),
            ],
          ],
        ),
        onLaunchUrl: _openReference,
        scrollable: false,
        expands: false,
        minHeight: compact ? 520 : 650,
        padding: EdgeInsets.fromLTRB(
          compact ? 24 : 64,
          28,
          compact ? 24 : 64,
          88,
        ),
        placeholder:
            'Comienza a escribir. El formato aparecerá directamente en la página.',
        customStyles: _quillStyles(context, compact),
        onTapOutsideEnabled: false,
      ),
    );
  }

  quill.DefaultStyles _quillStyles(BuildContext context, bool compact) {
    final defaults = quill.DefaultStyles.getInstance(context);
    final bodyStyle = TextStyle(
      color: AppColors.textPrimary,
      fontFamily: _serif ? 'CorvusLiterary' : 'sans-serif',
      fontSize: _fontSize,
      height: _lineHeight,
      letterSpacing: 0.05,
    );
    return quill.DefaultStyles(
      paragraph: defaults.paragraph?.copyWith(style: bodyStyle),
      h1: defaults.h1?.copyWith(
        style: bodyStyle.copyWith(
          fontSize: compact ? 27 : 31,
          height: 1.28,
          fontWeight: FontWeight.w700,
        ),
      ),
      h2: defaults.h2?.copyWith(
        style: bodyStyle.copyWith(
          fontSize: compact ? 22 : 25,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
      h3: defaults.h3?.copyWith(
          style: bodyStyle.copyWith(
              fontSize: _fontSize + 3, fontWeight: FontWeight.w700)),
      bold: bodyStyle.copyWith(fontWeight: FontWeight.w700),
      italic: bodyStyle.copyWith(fontStyle: FontStyle.italic),
      underline: bodyStyle.copyWith(decoration: TextDecoration.underline),
      strikeThrough: bodyStyle.copyWith(decoration: TextDecoration.lineThrough),
      link: bodyStyle.copyWith(
        color: AppColors.primaryLight,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primaryLight,
      ),
      quote: defaults.quote?.copyWith(
        style: bodyStyle.copyWith(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          border: Border(
            left: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.62),
              width: 3,
            ),
          ),
        ),
      ),
      lists: defaults.lists?.copyWith(style: bodyStyle),
      placeHolder: defaults.placeHolder?.copyWith(
        style: bodyStyle.copyWith(
          color: Colors.white.withValues(alpha: 0.22),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Future<void> _openComments() async {
    final selection = _bodyController.selection;
    final text = _bodyController.document.toPlainText();
    final anchor = AtelierTextAnchor.capture(
        text,
        selection.isValid ? selection.start : 0,
        selection.isValid ? selection.end : 0);
    if ((_isDirty || _node == null) && !await _save(silent: true)) return;
    if (!mounted || _node == null || _isDirty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AtelierCommentsSheet(
          profileId: widget.profileId,
          projectId: widget.projectId,
          nodeId: _node!.id,
          selection: anchor,
          currentText: () => _bodyController.document.toPlainText(),
          apply: (anchor, replacement) async {
            if (!_canEdit || !mounted) return false;
            final position =
                anchor.locate(_bodyController.document.toPlainText());
            if (position == null) return false;
            // La sugerencia conserva un punto recuperable incluso tras cerrar
            // el editor. Si el respaldo falla, no se modifica el manuscrito.
            await context.read<AtelierProvider>().createVersionSnapshot(
                  profileId: widget.profileId,
                  projectId: widget.projectId,
                  label: 'Antes de aceptar una sugerencia',
                  description:
                      'Copia previa a una revisión de ${_titleController.text.trim()}.',
                );
            if (!mounted ||
                anchor.locate(_bodyController.document.toPlainText()) !=
                    position) {
              return false;
            }
            _bodyController.replaceText(
                position,
                anchor.quote.length,
                replacement,
                TextSelection.collapsed(offset: position + replacement.length));
            return await _save(silent: true) && !_isDirty;
          }),
    );
  }

  Future<void> _openHistory() async {
    if ((_isDirty || _node == null) && !await _save(silent: true)) return;
    if (!mounted || _node == null || _isDirty) return;
    final provider = context.read<AtelierProvider>();
    final restored = await showAtelierHistory(context, provider, _node!);
    if (restored != true || !mounted) return;
    final node = provider.nodeById(_node!.id);
    if (node == null) return;
    _adoptNode(node);
  }

  Future<void> _openAppearance() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Apariencia de escritura'),
                        const Text(
                            'Estas preferencias no cambian el texto publicado.'),
                        SwitchListTile(
                            title: const Text('Fuente literaria'),
                            value: _serif,
                            onChanged: (value) {
                              setState(() => _serif = value);
                              refresh(() {});
                            }),
                        Text('Tamaño: ${_fontSize.round()}'),
                        Slider(
                            value: _fontSize,
                            min: 14,
                            max: 28,
                            divisions: 14,
                            label: '${_fontSize.round()}',
                            onChanged: (value) {
                              setState(() => _fontSize = value);
                              refresh(() {});
                            }),
                        Text('Interlineado: ${_lineHeight.toStringAsFixed(1)}'),
                        Slider(
                            value: _lineHeight,
                            min: 1.3,
                            max: 2.4,
                            divisions: 11,
                            label: _lineHeight.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() => _lineHeight = value);
                              refresh(() {});
                            }),
                      ],
                    )),
              )),
    );
    await _rememberAppearance();
  }

  Future<void> _openInspector(int tab) async {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    _panelTab = tab;
    if (_panelPinned && MediaQuery.sizeOf(context).width >= 1100) {
      setState(() => _panelOpen = true);
      unawaited(_rememberAppearance());
      return;
    }
    Widget panel(BuildContext ctx) => DefaultTabController(
          length: 2,
          initialIndex: tab,
          child: SafeArea(
              child: Column(children: [
            Row(children: [
              Expanded(
                  child: TabBar(
                      onTap: (value) {
                        _panelTab = value;
                        unawaited(_rememberAppearance());
                      },
                      tabs: const [Tab(text: 'Dossier'), Tab(text: 'Flujo')])),
              if (MediaQuery.sizeOf(context).width >= 1100)
                IconButton(
                    tooltip: 'Fijar panel',
                    icon: const Icon(Icons.push_pin_outlined),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _panelPinned = true;
                        _panelOpen = true;
                      });
                      unawaited(_rememberAppearance());
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _bodyFocusNode.requestFocus();
                      });
                    }),
              IconButton(
                  tooltip: 'Cerrar panel',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close)),
            ]),
            Expanded(
                child: TabBarView(children: [
              for (var i = 0; i < 2; i++)
                SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildInspectorPanel(tab: i)),
            ])),
          ])),
        );
    if (mobile) {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => SizedBox(
              height: MediaQuery.sizeOf(ctx).height * .75, child: panel(ctx)));
    } else {
      await showDialog<void>(
          context: context,
          builder: (ctx) => StatefulBuilder(
                builder: (ctx, refresh) => Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                      color: AppColors.surface,
                      child: SizedBox(
                        width: _panelWidth,
                        child: Row(children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (event) => refresh(() =>
                                _panelWidth = (_panelWidth - event.delta.dx)
                                    .clamp(300, 560)),
                            onHorizontalDragEnd: (_) => _rememberAppearance(),
                            child: const SizedBox(
                                width: 12,
                                child: Center(
                                    child:
                                        Icon(Icons.drag_indicator, size: 12))),
                          ),
                          Expanded(child: panel(ctx)),
                        ]),
                      )),
                ),
              ));
    }
  }

  Widget _buildPinnedInspector() => Material(
        color: AppColors.surface,
        child: Row(children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (event) => setState(() =>
                _panelWidth = (_panelWidth - event.delta.dx).clamp(300, 560)),
            onHorizontalDragEnd: (_) => _rememberAppearance(),
            child: const SizedBox(
                width: 12,
                child: Center(child: Icon(Icons.drag_indicator, size: 12))),
          ),
          Expanded(
              child: DefaultTabController(
            key: ValueKey(_panelTab),
            length: 2,
            initialIndex: _panelTab,
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: TabBar(
                        onTap: (value) {
                          _panelTab = value;
                          unawaited(_rememberAppearance());
                        },
                        tabs: const [
                      Tab(text: 'Dossier'),
                      Tab(text: 'Flujo')
                    ])),
                IconButton(
                    tooltip: 'Desfijar panel',
                    icon: const Icon(Icons.push_pin),
                    onPressed: () {
                      setState(() {
                        _panelPinned = false;
                        _panelOpen = false;
                      });
                      unawaited(_rememberAppearance());
                      _openInspector(_panelTab);
                    }),
                IconButton(
                    tooltip: 'Cerrar panel',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _panelOpen = false);
                      unawaited(_rememberAppearance());
                    }),
              ]),
              Expanded(
                  child: TabBarView(children: [
                for (var i = 0; i < 2; i++)
                  SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildInspectorPanel(tab: i)),
              ])),
            ]),
          )),
        ]),
      );
  Future<void> _openNavigator() async {
    final render = _quillKey.currentState?.renderEditor;
    final visibleOffset =
        render?.getPositionForOffset(const Offset(100, 230)).offset ?? 0;
    final target = await showModalBottomSheet<AtelierNavigationTarget>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AtelierManuscriptNavigator(
        headings:
            atelierDocumentOutline(atelierQuillDeltaJson(_bodyController)),
        text: _bodyController.document.toPlainText(),
        visibleOffset: visibleOffset,
        initialQuery: _searchQuery,
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      _searchQuery = target.query;
      _searchOffset = target.offset;
    });
    _jumpToOffset(target.offset);
  }

  void _jumpToOffset(int offset) {
    // Solo mueve la vista: mantiene cursor, selección e historial de deshacer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final render = _quillKey.currentState?.renderEditor;
      if (render == null || !_pageScrollController.hasClients) return;
      final safeOffset = offset.clamp(0, _bodyController.document.length - 1);
      final rect =
          render.getLocalRectForCaret(TextPosition(offset: safeOffset));
      final y = render.localToGlobal(rect.topLeft).dy;
      _pageScrollController.jumpTo((_pageScrollController.offset + y - 240)
          .clamp(0, _pageScrollController.position.maxScrollExtent)
          .toDouble());
      _updateSearchHighlight();
    });
  }

  void _moveSearch(int direction) {
    final matches = atelierFindOccurrences(
        _bodyController.document.toPlainText(), _searchQuery);
    if (matches.isEmpty) return;
    final current = matches.indexOf(_searchOffset);
    final next = current < 0 ? 0 : (current + direction) % matches.length;
    setState(() => _searchOffset = matches[next]);
    _jumpToOffset(_searchOffset);
  }

  Widget _buildSearchNavigation() {
    final matches = atelierFindOccurrences(
        _bodyController.document.toPlainText(), _searchQuery);
    final current = matches.indexOf(_searchOffset);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateSearchHighlight());
    return Row(children: [
      const SizedBox(width: 16),
      Expanded(
          child: Text(
              matches.isEmpty
                  ? 'Sin coincidencias'
                  : '${current + 1} de ${matches.length}: $_searchQuery',
              maxLines: 1,
              overflow: TextOverflow.ellipsis)),
      IconButton(
          tooltip: 'Coincidencia anterior',
          onPressed: matches.isEmpty ? null : () => _moveSearch(-1),
          icon: const Icon(Icons.keyboard_arrow_up)),
      IconButton(
          tooltip: 'Coincidencia siguiente',
          onPressed: matches.isEmpty ? null : () => _moveSearch(1),
          icon: const Icon(Icons.keyboard_arrow_down)),
      IconButton(
          tooltip: 'Cerrar búsqueda',
          onPressed: () => setState(() {
                _searchQuery = '';
                _searchRects.value = [];
              }),
          icon: const Icon(Icons.close)),
    ]);
  }

  void _updateSearchHighlight() {
    if (!mounted || _searchQuery.isEmpty) return;
    final render = _quillKey.currentState?.renderEditor;
    final surface = _manuscriptKey.currentContext?.findRenderObject();
    if (render == null || surface is! RenderBox) return;
    final text = _bodyController.document.toPlainText();
    if (_searchOffset < 0 ||
        _searchOffset + _searchQuery.length > text.length ||
        text
                .substring(_searchOffset, _searchOffset + _searchQuery.length)
                .toLowerCase() !=
            _searchQuery.toLowerCase()) {
      _searchRects.value = [];
      return;
    }
    final rectangles = <Rect>[];
    Rect caretRect(int offset) {
      final position = TextPosition(offset: offset);
      final line = render.childAtPosition(position);
      final rect =
          line.getLocalRectForCaret(line.globalToLocalPosition(position));
      return surface.globalToLocal(line.localToGlobal(rect.topLeft)) &
          rect.size;
    }

    // Dibuja encima sin añadir atributos ni cambiar la selección del documento.
    for (var i = _searchOffset; i < _searchOffset + _searchQuery.length; i++) {
      final a = caretRect(i);
      final b = caretRect(i + 1);
      final right =
          (a.top - b.top).abs() < 2 ? b.left : a.right + _fontSize / 2;
      rectangles.add(Rect.fromLTRB(a.left < right ? a.left : right, a.top,
          a.left > right ? a.left : right, a.bottom));
    }
    _searchRects.value = rectangles;
  }

  Widget _buildInspectorPanel({required int tab}) {
    return Column(
      children: [
        if (tab == 0)
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
                    _StatCapsule(
                        label: 'Caracteres', value: '$_characterCount'),
                    _StatCapsule(
                        label: 'Lectura', value: '${_readingMinutes}m'),
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
        if (tab == 1)
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
              fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        selected: active,
        child: IconButton(
          tooltip: tooltip ?? label,
          onPressed: onTap,
          isSelected: active,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor:
                active ? AppColors.primaryLight : AppColors.textSecondary,
            backgroundColor:
                active ? AppColors.primaryMuted : Colors.transparent,
          ),
          icon: Icon(icon, size: 20),
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor.withValues(alpha: 0.90),
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
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
          fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHighlight extends CustomPainter {
  final List<Rect> rectangles;
  const _SearchHighlight(this.rectangles);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.amber.withValues(alpha: .28);
    for (final rect in rectangles) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SearchHighlight oldDelegate) =>
      oldDelegate.rectangles != rectangles;
}

class _FocusShade extends CustomPainter {
  final Rect? band;
  const _FocusShade(this.band);
  @override
  void paint(Canvas canvas, Size size) {
    if (band == null) return;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(band!.intersect(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .22));
  }

  @override
  bool shouldRepaint(_FocusShade oldDelegate) => oldDelegate.band != band;
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
                  fontWeight: FontWeight.w700,
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
    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor:
                filled ? AppColors.primaryLight : AppColors.textSecondary),
      );
    }
    if (filled) {
      return FilledButton.icon(
          onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label));
    }
    return TextButton.icon(
        onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label));
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
