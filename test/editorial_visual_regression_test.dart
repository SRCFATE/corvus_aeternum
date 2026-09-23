import 'package:corvus_aeternum/features/work/reader_preferences.dart';
import 'package:corvus_aeternum/shared/widgets/formatted_manuscript_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('CorvusLiterary')
      ..addFont(rootBundle.load('assets/fonts/lora/Lora.ttf'));
    await font.load();
  });

  Future<void> renderPalettes(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'CorvusLiterary'),
      home: RepaintBoundary(
          key: const ValueKey('reader-palettes'),
          child: Row(
            children: [
              for (final palette in ReaderPalette.values)
                Expanded(
                    child: _Sample(
                        preferences: ReaderPreferences(palette: palette))),
            ],
          )),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('corvus-align'), findsNothing);
  }

  testWidgets('literary reader fits and remains legible in all palettes',
      (tester) async {
    await renderPalettes(tester);
    final samples = find.byType(_Sample);
    expect(samples, findsNWidgets(3));
    for (var i = 0; i < ReaderPalette.values.length; i++) {
      final preferences = ReaderPreferences(palette: ReaderPalette.values[i]);
      final foreground = preferences.foreground.computeLuminance();
      final background = preferences.background.computeLuminance();
      final contrast = foreground > background
          ? (foreground + .05) / (background + .05)
          : (background + .05) / (foreground + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      final bounds = tester.getRect(samples.at(i));
      final paragraphs = find.descendant(
          of: samples.at(i), matching: find.byType(SelectableText));
      expect(paragraphs, findsWidgets);
      for (final element in paragraphs.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(bounds.left));
        expect(rect.right, lessThanOrEqualTo(bounds.right));
        expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
      }
    }
  });

  // Keep the pixel baseline tied to Windows + Flutter 3.44.0. CI executes this
  // tag in its required Windows job; structural checks above run on Linux too.
  testWidgets(
      'literary reader preserves hierarchy and contrast in all palettes',
      (tester) async {
    await renderPalettes(tester);
    await expectLater(find.byKey(const ValueKey('reader-palettes')),
        matchesGoldenFile('goldens/literary_reader_palettes.png'));
  }, tags: ['golden']);
}

class _Sample extends StatelessWidget {
  final ReaderPreferences preferences;
  const _Sample({required this.preferences});
  @override
  Widget build(BuildContext context) => Material(
        color: preferences.background,
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.2)),
              child: FormattedManuscriptText(
                fontFamily: 'CorvusLiterary',
                fontSize: 18,
                lineHeight: 1.8,
                color: preferences.foreground,
                text: '## La biblioteca bajo la lluvia\n\n'
                    'El cuervo aguardaba en el alféizar. La ciudad había olvidado su nombre.\n\n'
                    '**Elena abrió el libro** y encontró _una frase_.\n\n'
                    '> No eran los libros los que guardaban silencio.\n\n'
                    '---\n\n'
                    '<!-- corvus-align:center -->\nLa primera señal\n\n'
                    '- Una puerta\n- Una voz\n\n'
                    '<u>Una promesa</u> y [un recuerdo](https://example.com).',
              ),
            )),
      );
}
