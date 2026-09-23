import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/global_search_service.dart';

class GlobalSearchDialog extends StatefulWidget {
  final String? profileId;
  final ValueChanged<String> onNavigate;
  final GlobalSearchService? service;
  const GlobalSearchDialog(
      {super.key, this.profileId, required this.onNavigate, this.service});
  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final _service = widget.service ?? GlobalSearchService();
  Timer? _debounce;
  int _generation = 0;
  int _selected = 0;
  bool _loading = false;
  bool _incomplete = false;
  String _category = 'Todo';
  List<String> _recent = [];
  List<GlobalSearchHit> _results = [];
  List<Map<String, dynamic>> _projects = [];
  String? _project;
  String? _status;
  int? _days;
  bool _showFilters = false;
  String get _historyKey => 'corvus.search.${widget.profileId ?? 'visitor'}';
  List<GlobalSearchHit> get _visible => _results
      .where((hit) => _category == 'Todo' || hit.category == _category)
      .toList();

  @override
  void initState() {
    super.initState();
    _loadRecent();
    if (widget.profileId != null) _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _service.projects();
      if (mounted) setState(() => _projects = projects);
    } catch (_) {/* La búsqueda general sigue disponible. */}
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _recent = prefs.getStringList(_historyKey) ?? []);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed(String query) {
    final generation = ++_generation;
    _debounce?.cancel();
    setState(() {
      _selected = 0;
      _loading = query.trim().isNotEmpty;
      _incomplete = false;
      if (query.trim().isEmpty) _results = [];
    });
    if (query.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final response = await _service.search(query,
            profileId: widget.profileId,
            filters: GlobalSearchFilters(
                projectId: _project,
                status: _status,
                since: _days == null
                    ? null
                    : DateTime.now().subtract(Duration(days: _days!))));
        if (!mounted || generation != _generation) return;
        setState(() {
          _results = response.hits;
          _incomplete = response.incomplete;
          _loading = false;
        });
      } catch (_) {
        if (mounted && generation == _generation) {
          setState(() {
            _loading = false;
            _incomplete = true;
          });
        }
      }
    });
  }

  void _open(GlobalSearchHit hit) {
    final query = _controller.text.trim();
    if (query.isNotEmpty) unawaited(_remember(query));
    widget.onNavigate(hit.route);
  }

  Future<void> _remember(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey,
          [query, ..._recent.where((item) => item != query)].take(6).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final results = _visible;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700 ? 12 : 40,
          vertical: 24),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent || results.isEmpty) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter &&
                        !_loading) {
                      _open(results[_selected.clamp(0, results.length - 1)]);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                        event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      setState(() => _selected = (_selected +
                              (event.logicalKey == LogicalKeyboardKey.arrowDown
                                  ? 1
                                  : -1)) %
                          results.length);
                      if (_scroll.hasClients) {
                        final target = (_selected *
                                88 *
                                MediaQuery.textScalerOf(context).scale(1))
                            .clamp(0, _scroll.position.maxScrollExtent)
                            .toDouble();
                        _scroll.jumpTo(target);
                      }
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    autofocus: true,
                    controller: _controller,
                    onChanged: _changed,
                    onSubmitted: (_) {
                      if (results.isNotEmpty && !_loading) {
                        _open(results[_selected.clamp(0, results.length - 1)]);
                      }
                    },
                    decoration: InputDecoration(
                        labelText: 'Buscar en Corvus',
                        hintText:
                            'Obras, capítulos, fichas, colecciones y perfiles',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                            tooltip: 'Cerrar búsqueda',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close))),
                  ),
                )),
            if (_loading)
              const LinearProgressIndicator(semanticsLabel: 'Buscando'),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters),
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filtros de búsqueda'))),
            if (_showFilters)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 12, children: [
                    if (_projects.isNotEmpty)
                      DropdownButton<String>(
                          value: _project,
                          hint: const Text('Todos los proyectos'),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todos los proyectos')),
                            for (final project in _projects)
                              DropdownMenuItem(
                                  value: project['id'] as String,
                                  child: SizedBox(
                                      width: 180,
                                      child: Text(project['title'] as String,
                                          overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: (value) {
                            setState(() => _project = value);
                            _changed(_controller.text);
                          }),
                    DropdownButton<String>(
                        value: _status,
                        hint: const Text('Todos los estados'),
                        items: [
                          const DropdownMenuItem<String>(
                              value: null, child: Text('Todos los estados')),
                          for (final entry in {
                            'draft': 'Borrador',
                            'review': 'En revisión',
                            'done': 'Terminado',
                            'published': 'Publicado'
                          }.entries)
                            DropdownMenuItem(
                                value: entry.key, child: Text(entry.value))
                        ],
                        onChanged: (value) {
                          setState(() => _status = value);
                          _changed(_controller.text);
                        }),
                    DropdownButton<int>(
                        value: _days,
                        hint: const Text('Cualquier fecha'),
                        items: const [
                          DropdownMenuItem<int>(
                              value: null, child: Text('Cualquier fecha')),
                          DropdownMenuItem(
                              value: 7, child: Text('Últimos 7 días')),
                          DropdownMenuItem(
                              value: 30, child: Text('Últimos 30 días'))
                        ],
                        onChanged: (value) {
                          setState(() => _days = value);
                          _changed(_controller.text);
                        }),
                  ])),
            if (_incomplete)
              ListTile(
                  title: const Text(
                      'No se pudieron consultar todas las secciones.'),
                  trailing: TextButton(
                      onPressed: () => _changed(_controller.text),
                      child: const Text('Reintentar'))),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final category in {
                    'Todo',
                    ..._results.map((hit) => hit.category)
                  })
                    Padding(
                        padding: const EdgeInsets.all(4),
                        child: ChoiceChip(
                            label: Text(category),
                            selected: _category == category,
                            onSelected: (_) => setState(() {
                                  _category = category;
                                  _selected = 0;
                                }))),
                ])),
            Expanded(
                child: _controller.text.trim().isEmpty
                    ? ListView(children: [
                        const ListTile(title: Text('Búsquedas recientes')),
                        if (_recent.isEmpty)
                          const ListTile(
                              title: Text(
                                  'Escribe un título, un nombre o una frase.')),
                        for (final query in _recent)
                          ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(query),
                              onTap: () {
                                _controller.text = query;
                                _changed(query);
                              }),
                      ])
                    : results.isEmpty && !_loading
                        ? const Center(
                            child:
                                Text('No hay resultados para esta búsqueda.'))
                        : ListView.builder(
                            controller: _scroll,
                            itemExtent:
                                88 * MediaQuery.textScalerOf(context).scale(1),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final hit = results[index];
                              return ListTile(
                                  selected: index == _selected,
                                  enabled: !_loading,
                                  title: _highlight(hit.title, lines: 1),
                                  subtitle: _highlight(
                                      '${hit.category} · ${hit.context}',
                                      lines: 2),
                                  onTap: () => _open(hit));
                            })),
          ])),
    );
  }

  Widget _highlight(String text, {required int lines}) {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return Text(text, maxLines: lines, overflow: TextOverflow.ellipsis);
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in RegExp(RegExp.escape(query), caseSensitive: false)
        .allMatches(text)) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
      spans.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline)));
      cursor = match.end;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(children: spans),
        maxLines: lines, overflow: TextOverflow.ellipsis);
  }
}
