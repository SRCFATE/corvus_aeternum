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

  testWidgets(
      'literary reader preserves hierarchy and contrast in all palettes',
      (tester) async {
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
    await expectLater(find.byKey(const ValueKey('reader-palettes')),
        matchesGoldenFile('goldens/literary_reader_palettes.png'));
  });
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
