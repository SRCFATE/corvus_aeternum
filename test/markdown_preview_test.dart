import 'package:corvus_aeternum/shared/widgets/corvus_markdown_preview.dart';
import 'package:corvus_aeternum/shared/widgets/corvus_text_field.dart';
import 'package:corvus_aeternum/shared/widgets/formatted_manuscript_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects block and inline Markdown without flagging plain text', () {
    expect(containsMarkdownSyntax('Texto sin formato'), isFalse);
    expect(containsMarkdownSyntax('# Titulo'), isTrue);
    expect(containsMarkdownSyntax('Un **secreto**'), isTrue);
    expect(containsMarkdownSyntax('[[Archivo interno]]'), isTrue);
  });

  testWidgets('CorvusTextField updates its Markdown preview while typing',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: CorvusTextField(
              controller: controller,
              label: 'Contenido',
              maxLines: 5,
            ),
          ),
        ),
      ),
    );

    expect(find.text('VISTA PREVIA'), findsNothing);
    await tester.enterText(find.byType(TextFormField), '# La torre');
    await tester.pump();

    expect(find.text('VISTA PREVIA'), findsOneWidget);
    expect(find.text('La torre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renderer supports headings, tasks, code and ordered lists',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormattedManuscriptText(
            text: '# Registro\n- [x] Canon\n1. Inicio\n`clave`',
          ),
        ),
      ),
    );

    expect(find.text('Registro'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.text('Canon'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
