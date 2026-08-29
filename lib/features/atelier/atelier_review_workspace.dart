import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/atelier_models.dart';
import '../../providers/atelier_provider.dart';
import '../../services/spanish_language_service.dart';
import '../../shared/widgets/corvus_markdown_preview.dart';

class AtelierReviewWorkspace extends StatefulWidget {
  final Color accent;
  final AtelierProvider atelier;

  const AtelierReviewWorkspace({
    super.key,
    required this.accent,
    required this.atelier,
  });

  @override
  State<AtelierReviewWorkspace> createState() => _AtelierReviewWorkspaceState();
}

class _AtelierReviewWorkspaceState extends State<AtelierReviewWorkspace> {
  final _language = SpanishLanguageService();
  final _bodyController = TextEditingController();
  final _dictionaryController = TextEditingController();
  Timer? _debounce;
  String? _selectedNodeId;
  List<LanguageSuggestion> _suggestions = const [];
  List<ThesaurusEntry> _dictionaryResults = const [];
  bool _saving = false;

  List<AtelierNode> get _documents {
    final result =
        widget.atelier.nodes.where((node) => node.kind != 'universe').toList()
          ..sort((a, b) {
            final contentOrder = (b.body.trim().isNotEmpty ? 1 : 0)
                .compareTo(a.body.trim().isNotEmpty ? 1 : 0);
            return contentOrder != 0
                ? contentOrder
                : b.updatedAt.compareTo(a.updatedAt);
          });
    return result;
  }

  AtelierNode? get _selectedNode {
    if (_documents.isEmpty) return null;
    return _documents.where((node) => node.id == _selectedNodeId).firstOrNull ??
        _documents.first;
  }

  @override
  void initState() {
    super.initState();
    _dictionaryResults = _language.searchThesaurus('');
    _bodyController.addListener(_queueAnalysis);
    _selectInitialDocument();
  }

  @override
  void didUpdateWidget(covariant AtelierReviewWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedNode == null && _documents.isNotEmpty) {
      _selectDocument(_documents.first);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _bodyController
      ..removeListener(_queueAnalysis)
      ..dispose();
    _dictionaryController.dispose();
    super.dispose();
  }

  void _selectInitialDocument() {
    if (_documents.isEmpty) return;
    _selectDocument(_documents.first, notify: false);
  }

  void _selectDocument(AtelierNode node, {bool notify = true}) {
    _debounce?.cancel();
    _selectedNodeId = node.id;
    _bodyController.value = TextEditingValue(
      text: node.body,
      selection: TextSelection.collapsed(offset: node.body.length),
    );
    _suggestions = _language.analyze(node.body);
    if (notify && mounted) setState(() {});
  }

  void _queueAnalysis() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _suggestions = _language.analyze(_bodyController.text));
    });
  }

  Future<void> _save() async {
    final node = _selectedNode;
    if (node == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.atelier
          .updateNode(node.copyWith(body: _bodyController.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revision guardada en Atelier.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applySuggestion(LanguageSuggestion suggestion, String replacement) {
    final next = _language.apply(_bodyController.text, suggestion, replacement);
    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (suggestion.offset + replacement.length).clamp(0, next.length),
      ),
    );
  }

  void _searchDictionary(String query) {
    setState(() => _dictionaryResults = _language.searchThesaurus(query));
  }

  void _insertSynonym(String synonym) {
    final text = _bodyController.text;
    var selection = _bodyController.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    var start = selection.start;
    var end = selection.end;
    if (selection.isCollapsed) {
      while (start > 0 && _isWordCharacter(text[start - 1])) {
        start--;
      }
      while (end < text.length && _isWordCharacter(text[end])) {
        end++;
      }
    }
    final source = start < end ? text.substring(start, end) : '';
    final replacement = _preserveCase(source, synonym);
    final next = text.replaceRange(start, end, replacement);
    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  bool _isWordCharacter(String character) =>
      RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(character);

  String _preserveCase(String source, String replacement) {
    if (source.isEmpty || replacement.isEmpty) return replacement;
    if (source.toUpperCase() == source) return replacement.toUpperCase();
    if (source[0].toUpperCase() == source[0]) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  }

  @override
  Widget build(BuildContext context) {
    final node = _selectedNode;
    final structuralIssues = widget.atelier.reviewIssues;
    final words = RegExp(r'\S+').allMatches(_bodyController.text).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewHeader(
          onSave: node == null ? null : _save,
          saving: _saving,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ReviewMetric(
                value: '${widget.atelier.projectHealth}%', label: 'salud'),
            _ReviewMetric(
                value: '${_suggestions.length}', label: 'correcciones'),
            _ReviewMetric(value: '$words', label: 'palabras'),
            _ReviewMetric(
                value: '${structuralIssues.length}',
                label: 'alertas de estructura'),
          ],
        ),
        const SizedBox(height: 14),
        if (node == null)
          const _ReviewSection(
            title: 'Editor de revision',
            icon: Icons.edit_note_rounded,
            child: Text(
              'Crea un capitulo, escena o nota para iniciar la correccion.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final editor = _ReviewEditor(
                documents: _documents,
                selectedNode: node,
                controller: _bodyController,
                suggestions: _suggestions,
                onSelectDocument: _selectDocument,
                onApplySuggestion: _applySuggestion,
              );
              final dictionary = _ThesaurusPanel(
                controller: _dictionaryController,
                results: _dictionaryResults,
                onSearch: _searchDictionary,
                onInsert: _insertSynonym,
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [editor, const SizedBox(height: 14), dictionary],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: editor),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: dictionary),
                ],
              );
            },
          ),
        const SizedBox(height: 14),
        _ReviewSection(
          title: 'Continuidad y estructura',
          icon: Icons.account_tree_outlined,
          child: structuralIssues.isEmpty
              ? const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.successLight),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text('No hay problemas estructurales detectados.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                )
              : Column(
                  children: structuralIssues
                      .map((issue) => _StructuralIssue(issue: issue))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  final VoidCallback? onSave;
  final bool saving;

  const _ReviewHeader({required this.onSave, required this.saving});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REVISION EDITORIAL',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              Text('Correccion y precision del manuscrito',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.15)),
              SizedBox(height: 5),
              Text(
                  'Ortografia, repeticiones, tipografia, sinonimos y continuidad en un solo espacio.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(saving ? 'Guardando' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  final String value;
  final String label;

  const _ReviewMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ReviewEditor extends StatelessWidget {
  final List<AtelierNode> documents;
  final AtelierNode selectedNode;
  final TextEditingController controller;
  final List<LanguageSuggestion> suggestions;
  final ValueChanged<AtelierNode> onSelectDocument;
  final void Function(LanguageSuggestion, String) onApplySuggestion;

  const _ReviewEditor({
    required this.documents,
    required this.selectedNode,
    required this.controller,
    required this.suggestions,
    required this.onSelectDocument,
    required this.onApplySuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return _ReviewSection(
      title: 'Documento activo',
      icon: Icons.edit_note_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedNode.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Texto de Atelier'),
            items: documents
                .map((node) => DropdownMenuItem(
                      value: node.id,
                      child: Text(node.title, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              onSelectDocument(documents.firstWhere((node) => node.id == id));
            },
          ),
          const SizedBox(height: 12),
          CorvusMarkdownFieldPreview(
            controller: controller,
            child: TextField(
              controller: controller,
              minLines: 12,
              maxLines: 22,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Escribe o revisa el texto seleccionado.',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.spellcheck_rounded,
                  size: 17, color: AppColors.warning),
              const SizedBox(width: 7),
              Text('${suggestions.length} sugerencias',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            const Text('No se detectaron incidencias en este texto.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            ...suggestions.take(12).map(
                  (suggestion) => _SuggestionRow(
                    suggestion: suggestion,
                    onApply: (replacement) =>
                        onApplySuggestion(suggestion, replacement),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final LanguageSuggestion suggestion;
  final ValueChanged<String> onApply;

  const _SuggestionRow({required this.suggestion, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final replacement = suggestion.replacements.firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 34,
            decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${suggestion.label} - ${suggestion.message}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                if (replacement != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      '"${suggestion.found}"  ->  "${replacement.isEmpty ? 'eliminar' : replacement}"',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (replacement != null)
            IconButton(
              tooltip: 'Aplicar correccion',
              onPressed: () => onApply(replacement),
              icon: const Icon(Icons.done_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class _ThesaurusPanel extends StatelessWidget {
  final TextEditingController controller;
  final List<ThesaurusEntry> results;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onInsert;

  const _ThesaurusPanel({
    required this.controller,
    required this.results,
    required this.onSearch,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    return _ReviewSection(
      title: 'Diccionario de sinonimos',
      icon: Icons.menu_book_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar palabra o sinonimo',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            const Text('No hay coincidencias en el diccionario editorial.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            ...results.take(5).map((entry) =>
                _ThesaurusEntryTile(entry: entry, onInsert: onInsert)),
        ],
      ),
    );
  }
}

class _ThesaurusEntryTile extends StatelessWidget {
  final ThesaurusEntry entry;
  final ValueChanged<String> onInsert;

  const _ThesaurusEntryTile({required this.entry, required this.onInsert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(entry.word,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900))),
              Text(entry.register,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.definition,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.synonyms
                .map((word) => ActionChip(
                      avatar: const Icon(Icons.swap_horiz_rounded, size: 14),
                      label: Text(word),
                      tooltip: 'Sustituir palabra seleccionada',
                      onPressed: () => onInsert(word),
                    ))
                .toList(),
          ),
          if (entry.antonyms.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text('Antonimos: ${entry.antonyms.join(', ')}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

class _StructuralIssue extends StatelessWidget {
  final AtelierReviewIssue issue;

  const _StructuralIssue({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(issue.detail,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ReviewSection(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
