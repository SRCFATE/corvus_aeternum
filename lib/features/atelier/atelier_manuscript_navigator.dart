import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'atelier_document_outline.dart';

class AtelierNavigationTarget {
  final int offset;
  final String query;
  const AtelierNavigationTarget(this.offset, {this.query = ''});
}

/// El índice y sus resaltados son una vista del documento; nunca lo editan.
class AtelierManuscriptNavigator extends StatefulWidget {
  final List<AtelierHeading> headings;
  final String text;
  final int visibleOffset;
  final String initialQuery;
  const AtelierManuscriptNavigator({
    super.key,
    required this.headings,
    required this.text,
    this.visibleOffset = 0,
    this.initialQuery = '',
  });

  @override
  State<AtelierManuscriptNavigator> createState() =>
      _AtelierManuscriptNavigatorState();
}

class _AtelierManuscriptNavigatorState
    extends State<AtelierManuscriptNavigator> {
  late final _query = TextEditingController(text: widget.initialQuery);
  final _collapsed = <int>{};
  final _results = ScrollController();
  int _selected = 0;

  List<int> get _matches => atelierFindOccurrences(widget.text, _query.text);

  @override
  void dispose() {
    _query.dispose();
    _results.dispose();
    super.dispose();
  }

  void _move(int direction) {
    final matches = _matches;
    if (matches.isEmpty) return;
    setState(() => _selected = (_selected + direction) % matches.length);
    if (_results.hasClients) {
      _results.jumpTo(
          (_selected * 80.0).clamp(0, _results.position.maxScrollExtent));
    }
  }

  void _openMatch(int index) {
    final matches = _matches;
    if (matches.isEmpty) return;
    Navigator.pop(
        context, AtelierNavigationTarget(matches[index], query: _query.text));
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final activeHeading = widget.headings
        .where((heading) => heading.offset <= widget.visibleOffset)
        .lastOrNull;
    final visibleHeadings = <AtelierHeading>[];
    int? hiddenLevel;
    for (final heading in widget.headings) {
      if (hiddenLevel != null && heading.level > hiddenLevel) continue;
      hiddenLevel = null;
      visibleHeadings.add(heading);
      if (_collapsed.contains(heading.offset)) hiddenLevel = heading.level;
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
      },
      child: SafeArea(
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                    labelText: 'Buscar en el capítulo',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() => _selected = 0),
                  onSubmitted: (_) => _openMatch(_selected),
                ),
              ),
              if (_query.text.isNotEmpty)
                Row(children: [
                  const SizedBox(width: 16),
                  Expanded(
                      child: Text(matches.isEmpty
                          ? 'No hay coincidencias'
                          : '${_selected + 1} de ${matches.length} coincidencias')),
                  IconButton(
                      tooltip: 'Coincidencia anterior',
                      onPressed: matches.isEmpty ? null : () => _move(-1),
                      icon: const Icon(Icons.keyboard_arrow_up)),
                  IconButton(
                      tooltip: 'Coincidencia siguiente',
                      onPressed: matches.isEmpty ? null : () => _move(1),
                      icon: const Icon(Icons.keyboard_arrow_down)),
                ]),
              Expanded(
                  child: _query.text.isNotEmpty
                      ? ListView.builder(
                          controller: _results,
                          itemExtent: 80,
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final position = matches[index];
                            final start =
                                (position - 30).clamp(0, widget.text.length);
                            final end = (position + _query.text.length + 60)
                                .clamp(0, widget.text.length);
                            String clean(String text) =>
                                text.replaceAll('\n', ' ');
                            return ListTile(
                              selected: index == _selected,
                              title: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                        text: clean(widget.text
                                            .substring(start, position))),
                                    TextSpan(
                                      text: clean(widget.text.substring(
                                          position,
                                          position + _query.text.length)),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline),
                                    ),
                                    TextSpan(
                                        text: clean(widget.text.substring(
                                            position + _query.text.length,
                                            end))),
                                  ]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () => _openMatch(index),
                            );
                          },
                        )
                      : ListView(children: [
                          if (visibleHeadings.isEmpty)
                            const ListTile(
                                title: Text(
                                    'Añade subtítulos para crear el índice.')),
                          for (final heading in visibleHeadings)
                            ListTile(
                              selected: identical(heading, activeHeading),
                              contentPadding: EdgeInsets.only(
                                  left: 16.0 * heading.level, right: 16),
                              title: Text(heading.title),
                              trailing: widget.headings
                                      .skipWhile((h) => !identical(h, heading))
                                      .skip(1)
                                      .take(1)
                                      .any((h) => h.level > heading.level)
                                  ? IconButton(
                                      tooltip:
                                          _collapsed.contains(heading.offset)
                                              ? 'Expandir sección'
                                              : 'Contraer sección',
                                      icon: Icon(
                                          _collapsed.contains(heading.offset)
                                              ? Icons.expand_more
                                              : Icons.expand_less),
                                      onPressed: () => setState(() {
                                        if (!_collapsed
                                            .remove(heading.offset)) {
                                          _collapsed.add(heading.offset);
                                        }
                                      }),
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context,
                                  AtelierNavigationTarget(heading.offset)),
                            ),
                        ])),
            ]),
          ),
        ),
      ),
    );
  }
}
