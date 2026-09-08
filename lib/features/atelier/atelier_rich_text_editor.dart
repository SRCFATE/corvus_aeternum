import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Editor visual compatible con los manuscritos Markdown existentes.
///
/// El texto sigue siendo portable, pero los delimitadores se vuelven invisibles
/// y su contenido se dibuja con el formato final mientras se escribe.
class AtelierRichTextController extends TextEditingController {
  AtelierRichTextController({super.text});

  bool _focusMode = false;

  bool get focusMode => _focusMode;

  set focusMode(bool value) {
    if (_focusMode == value) return;
    _focusMode = value;
    notifyListeners();
  }

  void toggleInline(String opening, [String? closing]) {
    final suffix = closing ?? opening;
    final current = value;
    final selection = current.selection.isValid
        ? current.selection
        : TextSelection.collapsed(offset: current.text.length);
    final start = selection.start;
    final end = selection.end;
    final hasWrapping = start >= opening.length &&
        end + suffix.length <= current.text.length &&
        current.text.substring(start - opening.length, start) == opening &&
        current.text.substring(end, end + suffix.length) == suffix;

    if (hasWrapping) {
      final next = current.text.replaceRange(end, end + suffix.length, '');
      final unwrapped = next.replaceRange(start - opening.length, start, '');
      value = TextEditingValue(
        text: unwrapped,
        selection: TextSelection(
          baseOffset: start - opening.length,
          extentOffset: end - opening.length,
        ),
      );
      return;
    }

    final selected = current.text.substring(start, end);
    final replacement = '$opening$selected$suffix';
    final next = current.text.replaceRange(start, end, replacement);
    value = TextEditingValue(
      text: next,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + opening.length)
          : TextSelection(
              baseOffset: start + opening.length,
              extentOffset: end + opening.length,
            ),
    );
  }

  void toggleBlock(String prefix) {
    final current = value;
    final selection = current.selection.isValid
        ? current.selection
        : TextSelection.collapsed(offset: current.text.length);
    final lineStart = selection.start == 0
        ? 0
        : current.text.lastIndexOf('\n', selection.start - 1) + 1;
    final nextBreak = current.text.indexOf('\n', selection.end);
    final lineEnd = nextBreak == -1 ? current.text.length : nextBreak;
    final selectedLines =
        current.text.substring(lineStart, lineEnd).split('\n');
    final allActive = selectedLines.every((line) => line.startsWith(prefix));
    final blockMarker = RegExp(r'^(#{1,3}\s+|>\s+|[-*•]\s+)');
    final replacement = selectedLines.map((line) {
      if (allActive) return line.substring(prefix.length);
      return '$prefix${line.replaceFirst(blockMarker, '')}';
    }).join('\n');
    final next = current.text.replaceRange(lineStart, lineEnd, replacement);
    value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
    );
  }

  void insertSeparator() {
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: text.length);
    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);
    final separator = '${before.endsWith('\n') || before.isEmpty ? '' : '\n'}'
        '⁂\n'
        '${after.startsWith('\n') || after.isEmpty ? '' : '\n'}';
    final offset = before.length + separator.length;
    value = TextEditingValue(
      text: '$before$separator$after',
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = (style ?? const TextStyle()).copyWith(
      color: style?.color ?? AppColors.textPrimary,
    );
    if (text.isEmpty) return TextSpan(style: base, text: '');

    final active = _activeParagraph(value);
    final children = <InlineSpan>[];
    var offset = 0;
    final lines = text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final lineEnd = offset + line.length;
      final muted = _focusMode && (lineEnd < active.$1 || offset > active.$2);
      final lineColor = base.color?.withValues(alpha: muted ? 0.22 : 1);
      final lineStyle = base.copyWith(color: lineColor);
      _appendVisualLine(children, line, lineStyle);
      if (index < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: lineStyle));
      }
      offset = lineEnd + 1;
    }
    return TextSpan(style: base, children: children);
  }

  void _appendVisualLine(
    List<InlineSpan> output,
    String line,
    TextStyle style,
  ) {
    if (const {'***', '---', '⁂'}.contains(line.trim())) {
      output.add(TextSpan(
        text: line,
        style: style.copyWith(
          color: AppColors.primaryLight.withValues(
            alpha: style.color?.a ?? 1,
          ),
          fontSize: (style.fontSize ?? 16) + 4,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
        ),
      ));
      return;
    }
    final block = RegExp(r'^(#{1,3}\s+|>\s+|[-*•]\s+)').firstMatch(line);
    var content = line;
    var contentStyle = style;
    if (block != null) {
      final marker = block.group(0)!;
      content = line.substring(marker.length);
      if (marker.startsWith('#')) {
        output.add(_hiddenMarker(marker, style));
        final level = marker.trim().length;
        contentStyle = style.copyWith(
          fontSize: (style.fontSize ?? 16) + (level == 1 ? 10 : 6),
          fontWeight: FontWeight.w900,
          height: 1.2,
        );
      } else if (marker.startsWith('>')) {
        output.add(_hiddenMarker(marker, style));
        contentStyle = style.copyWith(
          fontStyle: FontStyle.italic,
          color: style.color?.withValues(alpha: 0.76),
        );
      } else {
        output.add(TextSpan(
          text: marker,
          style: style.copyWith(
            color: AppColors.primaryLight.withValues(
              alpha: style.color?.a ?? 1,
            ),
            fontWeight: FontWeight.w900,
          ),
        ));
      }
    }
    _appendInline(output, content, contentStyle);
  }

  void _appendInline(
    List<InlineSpan> output,
    String source,
    TextStyle style,
  ) {
    final pattern = RegExp(
      r'(\*\*[^*\n]+\*\*|~~[^~\n]+~~|`[^`\n]+`|\[\[[^\]\n]+\]\]|\*[^*\n]+\*)',
    );
    var cursor = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start > cursor) {
        output.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      late final String opening;
      late final String closing;
      late final TextStyle formatted;
      if (token.startsWith('**')) {
        opening = closing = '**';
        formatted = style.copyWith(fontWeight: FontWeight.w900);
      } else if (token.startsWith('~~')) {
        opening = closing = '~~';
        formatted = style.copyWith(decoration: TextDecoration.lineThrough);
      } else if (token.startsWith('`')) {
        opening = closing = '`';
        formatted = style.copyWith(
          color: AppColors.gold,
          backgroundColor: Colors.black.withValues(alpha: 0.26),
          fontFamily: 'monospace',
        );
      } else if (token.startsWith('[[')) {
        opening = '[[';
        closing = ']]';
        formatted = style.copyWith(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.w800,
        );
      } else {
        opening = closing = '*';
        formatted = style.copyWith(fontStyle: FontStyle.italic);
      }
      output
        ..add(_hiddenMarker(opening, style))
        ..add(TextSpan(
          text: token.substring(opening.length, token.length - closing.length),
          style: formatted,
        ))
        ..add(_hiddenMarker(closing, style));
      cursor = match.end;
    }
    if (cursor < source.length) {
      output.add(TextSpan(text: source.substring(cursor), style: style));
    }
  }

  TextSpan _hiddenMarker(String marker, TextStyle style) {
    return TextSpan(
      text: marker,
      style: style.copyWith(
        color: Colors.transparent,
        fontSize: 0.01,
        letterSpacing: -0.01,
      ),
    );
  }

  (int, int) _activeParagraph(TextEditingValue current) {
    final caret = current.selection.isValid
        ? current.selection.extentOffset.clamp(0, current.text.length)
        : current.text.length;
    final startMarker =
        caret == 0 ? -1 : current.text.lastIndexOf('\n\n', caret - 1);
    final endMarker = current.text.indexOf('\n\n', caret);
    return (
      startMarker == -1 ? 0 : startMarker + 2,
      endMarker == -1 ? current.text.length : endMarker,
    );
  }
}

String atelierAlignmentName(TextAlign alignment) => switch (alignment) {
      TextAlign.right => 'right',
      TextAlign.center => 'center',
      TextAlign.justify => 'justify',
      _ => 'left',
    };

TextAlign atelierTextAlign(Object? value) => switch (value) {
      'right' => TextAlign.right,
      'center' => TextAlign.center,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };
