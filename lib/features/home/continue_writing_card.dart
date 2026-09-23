import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/supabase_config.dart';
import '../../core/live_refresh.dart';
import '../../services/atelier_comment_service.dart';
import '../atelier/atelier_writing_progress.dart';

class ContinueWritingCard extends StatefulWidget {
  final String profileId;
  const ContinueWritingCard({super.key, required this.profileId});
  @override
  State<ContinueWritingCard> createState() => _ContinueWritingCardState();
}

class _ContinueWritingCardState extends State<ContinueWritingCard> {
  Map<String, dynamic>? _node;
  List<Map<String, dynamic>> _reviews = [];
  int _weekly = 0;
  bool _hidden = false;
  bool _loading = true;
  String? _error;
  LiveRefresh? _liveRefresh;
  int _loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ContinueWritingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _liveRefresh?.dispose();
      _liveRefresh = null;
      _node = null;
      _reviews = [];
      _weekly = 0;
      _loading = true;
      _hidden = false;
      _error = null;
      _load();
    }
  }

  @override
  void dispose() {
    _liveRefresh?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = widget.profileId;
    final generation = ++_loadGeneration;
    bool isCurrent() => mounted && generation == _loadGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!isCurrent()) return;
      final hidden = prefs.getBool('corvus.home.hideWriting.$profile') == true;
      if (isCurrent()) {
        setState(() {
          _hidden = hidden;
          _loading = _node == null && _reviews.isEmpty;
          _error = null;
        });
      }
      if (hidden) {
        _liveRefresh?.dispose();
        _liveRefresh = null;
        return;
      }
      _liveRefresh ??=
          LiveRefresh(AtelierCommentService().watchChanges(), _load);
      final rows = await supabase
          .from('atelier_nodes')
          .select(
              'id,title,body,project_id,status,metadata,atelier_projects!atelier_nodes_project_id_fkey!inner(title,metadata,weekly_word_goal)')
          .eq('profile_id', profile)
          .inFilter('kind', ['chapter', 'scene', 'fragment'])
          .isFilter('metadata->>deleted_at', null)
          .isFilter('atelier_projects.metadata->>deleted_at', null)
          .order('updated_at', ascending: false)
          .limit(1);
      final node = rows.firstOrNull;
      var weekly = 0;
      if (node != null) {
        final progress = await supabase
            .from('atelier_nodes')
            .select('metadata')
            .eq('project_id', node['project_id'])
            .eq('metadata->>writing_week', writingWeekKey(DateTime.now()))
            .isFilter('metadata->>deleted_at', null);
        weekly = progress.fold<int>(
            0,
            (total, row) =>
                total +
                ((row['metadata'] as Map?)?['writing_words'] as num? ?? 0)
                    .toInt());
      }
      List<Map<String, dynamic>> reviews = [];
      try {
        reviews = await supabase
            .from('atelier_comments')
            .select(
                'project_id,node_id,atelier_projects!atelier_comments_project_id_fkey(title)')
            .eq('status', 'open')
            .neq('profile_id', profile)
            .order('created_at', ascending: false)
            .limit(30);
      } catch (_) {
        // Preserve the last known activity while a transient read fails.
        reviews = _reviews;
      }
      if (isCurrent()) {
        setState(() {
          _node = node;
          _weekly = weekly;
          _reviews = reviews;
        });
      }
    } catch (_) {
      if (isCurrent()) {
        setState(() => _error = 'No se pudo cargar tu actividad reciente.');
      }
    } finally {
      if (isCurrent()) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setHidden(bool hidden) async {
    final profile = widget.profileId;
    ++_loadGeneration;
    if (hidden) {
      _liveRefresh?.dispose();
      _liveRefresh = null;
    }
    setState(() => _hidden = hidden);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('corvus.home.hideWriting.$profile', hidden);
    } catch (_) {}
    if (!hidden && mounted && profile == widget.profileId) await _load();
  }

  void _open(Map<String, dynamic> node) =>
      context.push(Uri(path: '/atelier', queryParameters: {
        'project': node['project_id'] as String,
        if (node['id'] != null || node['node_id'] != null)
          'node': (node['id'] ?? node['node_id']) as String
      }).toString());
  @override
  Widget build(BuildContext context) {
    if (_hidden) {
      return Align(
          alignment: Alignment.centerRight,
          child: TextButton(
              onPressed: () => _setHidden(false),
              child: const Text('Mostrar continuidad')));
    }
    if (_loading && _node == null) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(
              semanticsLabel: 'Cargando actividad reciente'));
    }
    if (_error != null && _node == null && _reviews.isEmpty) {
      return ListTile(
          title: Text(_error!),
          trailing:
              TextButton(onPressed: _load, child: const Text('Reintentar')));
    }
    final node = _node;
    if (node == null && _reviews.isEmpty) return const SizedBox.shrink();
    final project = node?['atelier_projects'] as Map?;
    final goal = (project?['weekly_word_goal'] as num?)?.toInt() ?? 0;
    final metadata = project?['metadata'] as Map?;
    final snapshot = metadata?['publication_snapshot'];
    final saved = snapshot is List
        ? snapshot
            .whereType<Map>()
            .where((row) => row['id'] == node?['id'])
            .firstOrNull
        : null;
    final pending = metadata?['publication_work_id'] != null &&
        (saved?['body'] != node?['body'] || saved?['title'] != node?['title']);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final review in _reviews) {
      groups.putIfAbsent(review['project_id'] as String, () => []).add(review);
    }
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Tu actividad',
                            style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                        tooltip: 'Ocultar este módulo',
                        onPressed: () => _setHidden(true),
                        icon: const Icon(Icons.close))
                  ]),
                  if (_error != null)
                    TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(_error!)),
                  if (node != null) ...[
                    Text(
                        '${project?['title'] ?? 'Tu proyecto'} · ${node['title']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (pending)
                      const Text('Cambios pendientes de publicación'),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                            onPressed: () => _open(node),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Continuar escribiendo'))),
                    if (goal > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                          'Esta semana: $_weekly de $goal palabras añadidas y guardadas'),
                      LinearProgressIndicator(
                          value: (_weekly / goal).clamp(0, 1),
                          semanticsLabel: 'Objetivo semanal'),
                    ],
                  ],
                  for (final reviews in groups.values)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.comment_outlined),
                        title: Text(
                            '${(reviews.first['atelier_projects'] as Map?)?['title'] ?? 'Proyecto'}'),
                        subtitle: Text(
                            '${reviews.length} comentarios recientes por revisar'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(reviews.first)),
                ])));
  }
}
