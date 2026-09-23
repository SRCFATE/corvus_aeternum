import 'package:flutter/material.dart';
import '../../core/live_refresh.dart';
import '../../models/atelier_comment.dart';
import '../../services/atelier_comment_service.dart';

class AtelierCommentsSheet extends StatefulWidget {
  final String profileId;
  final String projectId;
  final String nodeId;
  final AtelierTextAnchor selection;
  final String Function() currentText;
  final Future<bool> Function(AtelierTextAnchor anchor, String replacement)
      apply;
  final AtelierCommentService? service;
  const AtelierCommentsSheet(
      {super.key,
      required this.profileId,
      required this.projectId,
      required this.nodeId,
      required this.selection,
      required this.currentText,
      required this.apply,
      this.service});
  @override
  State<AtelierCommentsSheet> createState() => _AtelierCommentsSheetState();
}

class _AtelierCommentsSheetState extends State<AtelierCommentsSheet> {
  late final _service = widget.service ?? AtelierCommentService();
  final _body = TextEditingController();
  final _replacement = TextEditingController();
  List<AtelierComment> _comments = [];
  List<String> _capabilities = [];
  bool _loading = true;
  bool _busy = false;
  bool _suggestion = false;
  String? _replyTo;
  String? _error;
  final _appliedSuggestions = <String>{};
  LiveRefresh? _liveRefresh;
  int _loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load();
    _liveRefresh = LiveRefresh(
        _service.watchChanges(projectId: widget.projectId), () async {
      if (_busy) {
        _liveRefresh?.request();
        return;
      }
      await _load();
    });
  }

  @override
  void dispose() {
    _liveRefresh?.dispose();
    _body.dispose();
    _replacement.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final result = await Future.wait([
        _service.load(widget.projectId, widget.nodeId),
        _service.capabilities(widget.projectId)
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _comments = result[0] as List<AtelierComment>;
        _capabilities = result[1] as List<String>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _error =
              'No se pudieron cargar los comentarios. Comprueba tu conexión y acceso al proyecto.';
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo completar la acción. Tu texto se conserva; puedes reintentar.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        if (_body.text.trim().isEmpty) return;
        final parent =
            _comments.where((comment) => comment.id == _replyTo).firstOrNull;
        await _service.add(
            projectId: widget.projectId,
            nodeId: widget.nodeId,
            profileId: widget.profileId,
            body: _body.text,
            parentId: _replyTo,
            suggestion: _suggestion && _replyTo == null,
            anchor: {
              ...(parent?.anchor ?? widget.selection.toMap()),
              if (_suggestion && _replyTo == null)
                'replacement': _replacement.text
            });
        if (mounted) {
          _body.clear();
          _replacement.clear();
          setState(() {
            _replyTo = null;
            _suggestion = false;
          });
        }
      });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: Column(children: [
                const ListTile(
                    title: Text('Revisión y comentarios'),
                    subtitle: Text('Comentar no modifica el manuscrito.')),
                if (_loading || _busy) const LinearProgressIndicator(),
                if (_error != null)
                  ListTile(
                      title: Text(_error!),
                      trailing: TextButton(
                          onPressed: _load, child: const Text('Reintentar'))),
                Expanded(
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                  if (_comments.isEmpty && !_loading)
                    const Text(
                        'Aún no hay comentarios. Selecciona un fragmento para iniciar la revisión.'),
                  for (final comment in _comments.where((comment) =>
                      comment.parentId == null ||
                      !_comments
                          .any((parent) => parent.id == comment.parentId))) ...[
                    _comment(comment),
                    for (final reply in _comments
                        .where((reply) => reply.parentId == comment.id))
                      Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _comment(reply)),
                  ],
                  if (_capabilities.contains('comment.create')) ...[
                    if (_replyTo != null)
                      ListTile(
                          title: const Text('Responder al comentario'),
                          trailing: IconButton(
                              tooltip: 'Cancelar respuesta',
                              onPressed: () => setState(() => _replyTo = null),
                              icon: const Icon(Icons.close))),
                    if (widget.selection.quote.isNotEmpty && _replyTo == null)
                      Text('Sobre: «${widget.selection.quote}»',
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    TextField(
                        controller: _body,
                        maxLines: 3,
                        maxLength: 8000,
                        decoration:
                            const InputDecoration(labelText: 'Comentario')),
                    if (widget.selection.quote.isNotEmpty && _replyTo == null)
                      SwitchListTile(
                          title: const Text('Proponer un reemplazo'),
                          value: _suggestion,
                          onChanged: (value) =>
                              setState(() => _suggestion = value)),
                    if (_suggestion && _replyTo == null)
                      TextField(
                          controller: _replacement,
                          maxLines: 3,
                          maxLength: 8000,
                          decoration: const InputDecoration(
                              labelText: 'Texto sugerido')),
                    FilledButton(
                        onPressed: _busy ? null : _send,
                        child: const Text('Añadir comentario')),
                  ] else if (!_loading && _error == null)
                    const Text('Tienes acceso de lectura a esta revisión.'),
                ])),
              ]),
            )));
  }

  Widget _comment(AtelierComment comment) {
    final anchor = AtelierTextAnchor.fromMap(comment.anchor);
    final orphan =
        anchor.quote.isNotEmpty && anchor.locate(widget.currentText()) == null;
    return Card(
        child: Padding(
            padding: EdgeInsets.all(comment.parentId == null ? 16 : 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${comment.author} · ${comment.createdAt.toLocal().toString().substring(0, 16)}'),
              if (comment.parentId != null) const Text('Respuesta'),
              if (anchor.quote.isNotEmpty)
                Text('«${anchor.quote}»',
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              if (orphan)
                const Text(
                    'El fragmento cambió o se eliminó. Revisa el contexto antes de continuar.'),
              Text(comment.body),
              if (comment.kind == 'suggestion')
                Text('Propuesta: ${comment.anchor['replacement'] ?? ''}'),
              if (comment.status == 'resolved') const Text('Resuelto'),
              if (comment.status == 'open')
                Wrap(spacing: 8, children: [
                  if (_capabilities.contains('comment.create'))
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _replyTo = comment.parentId ?? comment.id;
                                  _suggestion = false;
                                }),
                        child: const Text('Responder')),
                  if (_capabilities.contains('comment.resolve'))
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => _service.resolve(
                                widget.projectId, comment, widget.profileId)),
                        child: const Text('Resolver')),
                  if (comment.kind == 'suggestion' &&
                      _capabilities.contains('project.write') &&
                      _capabilities.contains('comment.resolve')) ...[
                    TextButton(
                        onPressed: _busy ||
                                (orphan &&
                                    !_appliedSuggestions.contains(comment.id))
                            ? null
                            : () => _run(() async {
                                  if (!_appliedSuggestions
                                      .contains(comment.id)) {
                                    if (!await widget.apply(
                                        anchor,
                                        comment.anchor['replacement']
                                                as String? ??
                                            '')) {
                                      throw StateError('El fragmento cambió');
                                    }
                                    _appliedSuggestions.add(comment.id);
                                  }
                                  await _service.resolve(widget.projectId,
                                      comment, widget.profileId,
                                      resolution: 'accepted');
                                }),
                        child: const Text('Aceptar')),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => _service.resolve(
                                widget.projectId, comment, widget.profileId,
                                resolution: 'rejected')),
                        child: const Text('Rechazar')),
                  ],
                ]),
            ])));
  }
}
