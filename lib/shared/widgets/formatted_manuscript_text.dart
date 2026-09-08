import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FormattedManuscriptText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double lineHeight;
  final Color color;
  final bool selectable;

  const FormattedManuscriptText({
    super.key,
    required this.text,
    this.fontSize = 16,
    this.lineHeight = 1.9,
    this.color = AppColors.textPrimary,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map((block) => Padding(
                padding: EdgeInsets.only(bottom: block.spacingAfter(fontSize)),
                child: _buildBlock(block),
              ))
          .toList(growable: false),
    );
  }

  Widget _buildBlock(_ManuscriptBlock block) {
    switch (block.kind) {
      case _BlockKind.heading:
        return _richText(
          block.text,
          TextStyle(
            color: AppColors.textPrimary,
            fontSize: fontSize +
                switch (block.level) {
                  1 => 10,
                  2 => 6,
                  _ => 3,
                },
            fontWeight: FontWeight.w900,
            height: 1.18,
          ),
          textAlign: block.textAlign,
        );
      case _BlockKind.quote:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.55),
                width: 3,
              ),
            ),
          ),
          child: _richText(
            block.text,
            TextStyle(
              color: color.withValues(alpha: 0.76),
              fontSize: fontSize,
              height: lineHeight,
              fontStyle: FontStyle.italic,
            ),
            textAlign: block.textAlign,
          ),
        );
      case _BlockKind.listItem:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: block.checked == null
                  ? Text(
                      block.marker ?? '•',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: fontSize * 0.9,
                        height: lineHeight,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.only(top: fontSize * 0.34),
                      child: Icon(
                        block.checked!
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: block.checked!
                            ? AppColors.successLight
                            : AppColors.textMuted,
                        size: fontSize + 2,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _paragraph(block.text, block.textAlign)),
          ],
        );
      case _BlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SelectableText(
            block.text,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.88),
              fontFamily: 'monospace',
              fontSize: fontSize * 0.88,
              height: 1.55,
            ),
          ),
        );
      case _BlockKind.divider:
        return Center(
          child: Container(
            width: 56,
            height: 2,
            margin: EdgeInsets.symmetric(vertical: fontSize * 0.8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      case _BlockKind.paragraph:
        return _paragraph(block.text, block.textAlign);
    }
  }

  Widget _paragraph(String value, TextAlign textAlign) {
    return _richText(
      value,
      TextStyle(
        color: color,
        fontSize: fontSize,
        height: lineHeight,
      ),
      textAlign: textAlign,
    );
  }

  Widget _richText(
    String value,
    TextStyle style, {
    TextAlign textAlign = TextAlign.left,
  }) {
    final span = TextSpan(style: style, children: _inlineSpans(value, style));
    return SizedBox(
      width: double.infinity,
      child: selectable
          ? SelectableText.rich(span, textAlign: textAlign)
          : RichText(text: span, textAlign: textAlign),
    );
  }

  List<InlineSpan> _inlineSpans(String value, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    while (cursor < value.length) {
      if (value.startsWith('[[', cursor)) {
        final end = value.indexOf(']]', cursor + 2);
        if (end != -1) {
          spans.add(TextSpan(
            text: value.substring(cursor + 2, end),
            style: baseStyle.copyWith(
              color: AppColors.primaryLight.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
            ),
          ));
          cursor = end + 2;
          continue;
        }
      }

      if (value.startsWith('[', cursor)) {
        final link = RegExp(r'^\[([^\]\n]+)\]\(([^)\n]+)\)')
            .firstMatch(value.substring(cursor));
        if (link != null) {
          spans.addAll(_inlineSpans(
            link.group(1)!,
            baseStyle.copyWith(
              color: AppColors.primaryLight,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primaryLight,
            ),
          ));
          cursor += link.end;
          continue;
        }
      }

      if (value.startsWith('`', cursor)) {
        final end = value.indexOf('`', cursor + 1);
        if (end != -1) {
          spans.add(TextSpan(
            text: value.substring(cursor + 1, end),
            style: baseStyle.copyWith(
              color: AppColors.gold,
              backgroundColor: Colors.black.withValues(alpha: 0.28),
              fontFamily: 'monospace',
            ),
          ));
          cursor = end + 1;
          continue;
        }
      }

      if (value.startsWith('<u>', cursor)) {
        final end = value.indexOf('</u>', cursor + 3);
        if (end != -1) {
          spans.addAll(_inlineSpans(
            value.substring(cursor + 3, end),
            baseStyle.copyWith(decoration: TextDecoration.underline),
          ));
          cursor = end + 4;
          continue;
        }
      }

      final marker = value.startsWith('***', cursor)
          ? '***'
          : value.startsWith('**', cursor)
              ? '**'
              : value.startsWith('~~', cursor)
                  ? '~~'
                  : value.startsWith('*', cursor)
                      ? '*'
                      : value.startsWith('_', cursor)
                          ? '_'
                          : null;
      if (marker != null) {
        final end = value.indexOf(marker, cursor + marker.length);
        if (end != -1) {
          final nestedStyle = switch (marker) {
            '***' => baseStyle.copyWith(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            '**' => baseStyle.copyWith(fontWeight: FontWeight.w900),
            '~~' => baseStyle.copyWith(
                decoration: TextDecoration.lineThrough,
                color: baseStyle.color?.withValues(alpha: 0.64),
              ),
            _ => baseStyle.copyWith(fontStyle: FontStyle.italic),
          };
          spans.addAll(_inlineSpans(
            value.substring(cursor + marker.length, end),
            nestedStyle,
          ));
          cursor = end + marker.length;
          continue;
        }
      }

      final next = _nextInlineMarker(value, cursor + 1);
      spans.add(TextSpan(
        text: _unescapeMarkdown(value.substring(cursor, next)),
        style: baseStyle,
      ));
      cursor = next;
    }
    return spans;
  }

  int _nextInlineMarker(String value, int start) {
    final positions = <int>[
      value.indexOf('**', start),
      value.indexOf('~~', start),
      value.indexOf('[[', start),
      value.indexOf('[', start),
      value.indexOf('`', start),
      value.indexOf('<u>', start),
      value.indexOf('*', start),
      value.indexOf('_', start),
    ].where((position) => position >= 0).toList();
    if (positions.isEmpty) return value.length;
    positions.sort();
    return positions.first;
  }

  String _unescapeMarkdown(String value) => value.replaceAllMapped(
        RegExp(r'\\([\\`*_{}\[\]()#+\-.!><])'),
        (match) => match.group(1)!,
      );

  List<_ManuscriptBlock> _parseBlocks(String source) {
    final blocks = <_ManuscriptBlock>[];
    final paragraph = StringBuffer();
    final code = StringBuffer();
    var inCodeBlock = false;
    var textAlign = TextAlign.left;

    void flushParagraph() {
      final value = paragraph.toString().trim();
      if (value.isNotEmpty) {
        blocks.add(_ManuscriptBlock(
          _BlockKind.paragraph,
          value,
          textAlign: textAlign,
        ));
      }
      paragraph.clear();
    }

    for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          blocks.add(_ManuscriptBlock(
            _BlockKind.code,
            code.toString().trimRight(),
          ));
          code.clear();
          inCodeBlock = false;
        } else {
          flushParagraph();
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        if (code.isNotEmpty) code.writeln();
        code.write(rawLine);
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }
      final alignment = RegExp(
        r'^<!--\s*corvus-align:(left|right|center|justify)\s*-->$',
      ).firstMatch(trimmed);
      if (alignment != null) {
        flushParagraph();
        textAlign = switch (alignment.group(1)) {
          'right' => TextAlign.right,
          'center' => TextAlign.center,
          'justify' => TextAlign.justify,
          _ => TextAlign.left,
        };
        continue;
      }
      if (trimmed == '***' || trimmed == '---' || trimmed == '⁂') {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.divider,
          '',
          textAlign: textAlign,
        ));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.heading,
          trimmed.substring(2).trim(),
          level: 1,
          textAlign: textAlign,
        ));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.heading,
          trimmed.substring(3).trim(),
          level: 2,
          textAlign: textAlign,
        ));
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.heading,
          trimmed.substring(4).trim(),
          level: 3,
          textAlign: textAlign,
        ));
        continue;
      }
      if (trimmed.startsWith('> ')) {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.quote,
          trimmed.substring(2).trim(),
          textAlign: textAlign,
        ));
        continue;
      }
      final taskMatch =
          RegExp(r'^[-*]\s+\[([ xX])\]\s+(.+)$').firstMatch(trimmed);
      if (taskMatch != null) {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.listItem,
          taskMatch.group(2)!.trim(),
          checked: taskMatch.group(1)!.toLowerCase() == 'x',
          textAlign: textAlign,
        ));
        continue;
      }
      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('• ')) {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.listItem,
          trimmed.substring(2).trim(),
          marker: '•',
          textAlign: textAlign,
        ));
        continue;
      }
      final orderedMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(trimmed);
      if (orderedMatch != null) {
        flushParagraph();
        blocks.add(_ManuscriptBlock(
          _BlockKind.listItem,
          orderedMatch.group(2)!.trim(),
          marker: '${orderedMatch.group(1)}.',
          textAlign: textAlign,
        ));
        continue;
      }

      if (paragraph.isNotEmpty) paragraph.write(' ');
      paragraph.write(trimmed);
    }

    if (inCodeBlock && code.isNotEmpty) {
      blocks
          .add(_ManuscriptBlock(_BlockKind.code, code.toString().trimRight()));
    }

    flushParagraph();
    return blocks;
  }
}

enum _BlockKind { paragraph, heading, quote, listItem, code, divider }

class _ManuscriptBlock {
  final _BlockKind kind;
  final String text;
  final int level;
  final String? marker;
  final bool? checked;
  final TextAlign textAlign;

  const _ManuscriptBlock(
    this.kind,
    this.text, {
    this.level = 1,
    this.marker,
    this.checked,
    this.textAlign = TextAlign.left,
  });

  double spacingAfter(double fontSize) {
    return switch (kind) {
      _BlockKind.heading => fontSize * 0.95,
      _BlockKind.quote => fontSize * 0.75,
      _BlockKind.listItem => fontSize * 0.35,
      _BlockKind.code => fontSize * 0.75,
      _BlockKind.divider => fontSize * 0.5,
      _BlockKind.paragraph => fontSize * 0.85,
    };
  }
}
