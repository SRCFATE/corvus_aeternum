import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

const atelierRichTextDeltaKey = 'rich_text_delta';

final _alignmentDirective = RegExp(
  r'^<!--\s*corvus-align:(left|right|center|justify)\s*-->$',
);

QuillController createAtelierQuillController({
  required String body,
  required Map<String, dynamic> metadata,
}) {
  final storedDelta = metadata[atelierRichTextDeltaKey];
  if (storedDelta is List) {
    try {
      return QuillController(
        document: Document.fromJson(storedDelta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      // Un documento antiguo o incompleto vuelve a abrirse desde Markdown.
    }
  }

  final parsed = _extractAlignmentDirectives(body);
  final converter = MarkdownToDelta(
    markdownDocument: md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    ),
  );
  final delta = converter.convert(parsed.markdown);
  final controller = QuillController(
    document: Document.fromDelta(delta),
    selection: const TextSelection.collapsed(offset: 0),
  );

  final legacyAlignment = _alignmentName(metadata['text_alignment']);
  final alignments = parsed.alignments.isEmpty
      ? List<String>.filled(
          _lineCount(controller.document.toPlainText()),
          legacyAlignment,
        )
      : parsed.alignments;
  _applyLineAlignments(controller, alignments);
  controller.updateSelection(
    const TextSelection.collapsed(offset: 0),
    ChangeSource.local,
  );
  return controller;
}

List<Map<String, dynamic>> atelierQuillDeltaJson(QuillController controller) {
  return controller.document
      .toDelta()
      .toJson()
      .map((operation) => Map<String, dynamic>.from(operation))
      .toList(growable: false);
}

String atelierQuillToMarkdown(QuillController controller) {
  final delta = controller.document.toDelta();
  final alignments = _deltaLineAlignments(delta.toJson());
  var completedLines = 0;

  final converter = DeltaToMarkdown(
    customContentHandler: DeltaToMarkdown.escapeSpecialCharactersRelaxed,
    customTextAttrsHandlers: {
      Attribute.underline.key: CustomAttributeHandler(
        beforeContent: (_, __, output) => output.write('<u>'),
        afterContent: (_, __, output) => output.write('</u>'),
      ),
      Attribute.link.key: CustomAttributeHandler(
        beforeContent: (attribute, _, output) {
          final value = attribute.value?.toString() ?? '';
          output.write(value.startsWith('wikilink:') ? '[[' : '[');
        },
        afterContent: (attribute, _, output) {
          final value = attribute.value?.toString() ?? '';
          output.write(
            value.startsWith('wikilink:') ? ']]' : ']($value)',
          );
        },
      ),
    },
    visitLineHandleNewLine: (_, output) {
      output
        ..writeln()
        ..writeln();
      completedLines++;
      if (completedLines < alignments.length) {
        output.writeln(_alignmentMarker(alignments[completedLines]));
      }
    },
  );

  final markdown = converter.convert(delta).trimRight();
  if (markdown.isEmpty) return '';
  final firstAlignment = alignments.isEmpty ? 'left' : alignments.first;
  return '${_alignmentMarker(firstAlignment)}\n$markdown';
}

String atelierPrimaryAlignment(QuillController controller) {
  final alignments =
      _deltaLineAlignments(controller.document.toDelta().toJson()).toSet();
  return alignments.length == 1 ? alignments.first : 'mixed';
}

Attribute<String?> atelierAlignmentAttribute(TextAlign alignment) =>
    switch (alignment) {
      TextAlign.center => Attribute.centerAlignment,
      TextAlign.right => Attribute.rightAlignment,
      TextAlign.justify => Attribute.justifyAlignment,
      _ => Attribute.leftAlignment,
    };

TextAlign atelierAttributeTextAlign(Object? value) => switch (value) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };

({String markdown, List<String> alignments}) _extractAlignmentDirectives(
  String source,
) {
  var currentAlignment = 'left';
  final cleaned = <String>[];
  final alignments = <String>[];
  for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
    final directive = _alignmentDirective.firstMatch(rawLine.trim());
    if (directive != null) {
      currentAlignment = directive.group(1)!;
      continue;
    }
    cleaned.add(rawLine);
    if (rawLine.trim().isNotEmpty) alignments.add(currentAlignment);
  }
  return (markdown: cleaned.join('\n'), alignments: alignments);
}

void _applyLineAlignments(
  QuillController controller,
  List<String> alignments,
) {
  if (alignments.isEmpty) return;
  final plainText = controller.document.toPlainText();
  var lineStart = 0;
  var lineIndex = 0;
  for (var offset = 0; offset < plainText.length; offset++) {
    if (plainText.codeUnitAt(offset) != 10) continue;
    final alignment =
        alignments[lineIndex.clamp(0, alignments.length - 1).toInt()];
    controller.formatText(
      lineStart,
      offset - lineStart + 1,
      atelierAlignmentAttribute(atelierAttributeTextAlign(alignment)),
    );
    lineStart = offset + 1;
    lineIndex++;
  }
}

List<String> _deltaLineAlignments(List<dynamic> operations) {
  final result = <String>[];
  for (final rawOperation in operations) {
    if (rawOperation is! Map) continue;
    final inserted = rawOperation['insert'];
    if (inserted is! String || !inserted.contains('\n')) continue;
    final attributes = rawOperation['attributes'];
    final alignment = attributes is Map
        ? _alignmentName(attributes[Attribute.align.key])
        : 'left';
    for (var index = 0; index < inserted.length; index++) {
      if (inserted.codeUnitAt(index) == 10) result.add(alignment);
    }
  }
  return result;
}

int _lineCount(String value) {
  final breaks = RegExp(r'\n').allMatches(value).length;
  return breaks == 0 ? 1 : breaks;
}

String _alignmentName(Object? value) => switch (value) {
      'center' => 'center',
      'right' => 'right',
      'justify' => 'justify',
      _ => 'left',
    };

String _alignmentMarker(String alignment) =>
    '<!-- corvus-align:${_alignmentName(alignment)} -->';
