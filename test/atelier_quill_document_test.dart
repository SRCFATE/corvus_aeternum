import 'package:corvus_aeternum/features/atelier/atelier_quill_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrates existing Markdown into a visual document', () {
    final controller = createAtelierQuillController(
      body: '# Título\n\nUn **secreto** y una *duda*',
      metadata: const {'text_alignment': 'justify'},
    );
    addTearDown(controller.dispose);

    expect(controller.document.toPlainText(), contains('Título'));
    expect(
        controller.document.toPlainText(), contains('Un secreto y una duda'));
    final secretStart = controller.document.toPlainText().indexOf('secreto');
    controller.updateSelection(
      TextSelection(baseOffset: secretStart, extentOffset: secretStart + 7),
      quill.ChangeSource.local,
    );
    final style = controller.getSelectionStyle();
    expect(style.attributes[quill.Attribute.bold.key]?.value, isTrue);
  });

  test('migrates a Markdown scene divider as one visual ornament', () {
    final controller = createAtelierQuillController(
      body: 'Antes\n\n***\n\nDespués',
      metadata: const {},
    );
    addTearDown(controller.dispose);

    final markdown = atelierQuillToMarkdown(controller);
    expect(markdown, contains('\n⁂\n'));
    expect(markdown, isNot(contains('- - -')));
  });

  test('combines inline formats on the same selected segment', () {
    final controller = createAtelierQuillController(
      body: 'Texto combinado',
      metadata: const {},
    );
    addTearDown(controller.dispose);

    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      quill.ChangeSource.local,
    );
    controller
      ..formatSelection(quill.Attribute.bold)
      ..formatSelection(quill.Attribute.italic)
      ..formatSelection(quill.Attribute.underline);

    final firstOperation = controller.document.toDelta().toJson().first;
    final attributes =
        Map<String, dynamic>.from(firstOperation['attributes'] as Map);
    expect(attributes[quill.Attribute.bold.key], isTrue);
    expect(attributes[quill.Attribute.italic.key], isTrue);
    expect(attributes[quill.Attribute.underline.key], isTrue);

    final markdown = atelierQuillToMarkdown(controller);
    expect(markdown, contains('**'));
    expect(markdown, contains('_'));
    expect(markdown, contains('<u>'));
  });

  test('does not persist redundant markers for left-aligned text', () {
    final controller = createAtelierQuillController(
      body: 'Primer párrafo\n\nSegundo párrafo',
      metadata: const {},
    );
    addTearDown(controller.dispose);

    expect(atelierQuillToMarkdown(controller), isNot(contains('corvus-align')));
  });

  test('stores alignment independently for selected paragraphs', () {
    final controller = createAtelierQuillController(
      body: 'Primer párrafo\n\nSegundo párrafo',
      metadata: const {},
    );
    addTearDown(controller.dispose);

    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 14),
      quill.ChangeSource.local,
    );
    controller.formatSelection(quill.Attribute.centerAlignment);
    final secondStart = controller.document.toPlainText().indexOf('Segundo');
    controller.updateSelection(
      TextSelection(baseOffset: secondStart, extentOffset: secondStart + 7),
      quill.ChangeSource.local,
    );
    controller.formatSelection(quill.Attribute.rightAlignment);

    final markdown = atelierQuillToMarkdown(controller);
    expect(markdown, contains('<!-- corvus-align:center -->'));
    expect(markdown, contains('<!-- corvus-align:right -->'));
    expect(atelierPrimaryAlignment(controller), 'mixed');

    final reopened = createAtelierQuillController(
      body: markdown,
      metadata: {atelierRichTextDeltaKey: atelierQuillDeltaJson(controller)},
    );
    addTearDown(reopened.dispose);
    reopened.updateSelection(
      const TextSelection.collapsed(offset: 1),
      quill.ChangeSource.local,
    );
    expect(
      reopened.getSelectionStyle().attributes[quill.Attribute.align.key]?.value,
      'center',
    );
  });
}
