import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Campo de etiquetas estilo Corvus: se escriben separadas por coma (o Enter)
/// y se despliegan como pills con ✕ debajo del recuadro.
class CorvusTagInput extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  /// Sugerencias rápidas mostradas como pills fantasma (tap para añadir).
  final List<String> suggestions;
  final int maxTags;

  const CorvusTagInput({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.hint = 'Separa las etiquetas con una coma',
    this.suggestions = const [],
    this.maxTags = 20,
  });

  @override
  State<CorvusTagInput> createState() => _CorvusTagInputState();
}

class _CorvusTagInputState extends State<CorvusTagInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final additions = <String>[];
    for (final part in raw.split(',')) {
      final tag = part.trim().toLowerCase();
      if (tag.isEmpty) continue;
      if (widget.values.contains(tag) || additions.contains(tag)) continue;
      if (widget.values.length + additions.length >= widget.maxTags) break;
      additions.add(tag);
    }
    if (additions.isNotEmpty) {
      widget.onChanged([...widget.values, ...additions]);
    }
  }

  void _onTextChanged(String text) {
    if (!text.contains(',')) return;
    final lastComma = text.lastIndexOf(',');
    final complete = text.substring(0, lastComma);
    final remainder = text.substring(lastComma + 1).trimLeft();
    _commit(complete);
    _controller.value = TextEditingValue(
      text: remainder,
      selection: TextSelection.collapsed(offset: remainder.length),
    );
  }

  void _onSubmitted(String text) {
    _commit(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _remove(String tag) {
    widget.onChanged(widget.values.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    final pendingSuggestions = widget.suggestions
        .where((s) => !widget.values.contains(s.toLowerCase()))
        .toList();
    final atLimit = widget.values.length >= widget.maxTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (widget.values.isNotEmpty)
              Text(
                '${widget.values.length}/${widget.maxTags}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !atLimit,
            onChanged: _onTextChanged,
            onSubmitted: _onSubmitted,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: atLimit ? 'Límite de etiquetas alcanzado' : widget.hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
        ),

        // Pills
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.values.map((tag) => _TagPill(
                  label: tag,
                  onRemove: () => _remove(tag),
                )).toList(),
          ),
        ],

        // Sugerencias
        if (pendingSuggestions.isNotEmpty && !atLimit) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pendingSuggestions.map((s) => _SuggestionPill(
                  label: s,
                  onTap: () => _commit(s),
                )).toList(),
          ),
        ],
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagPill({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 7, 9, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded,
                  size: 12, color: Colors.white.withValues(alpha: 0.30)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
