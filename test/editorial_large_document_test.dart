import 'package:corvus_aeternum/features/atelier/atelier_document_outline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a 100000-word manuscript retains outline and Unicode search offsets',
      () {
    final delta = <Map<String, dynamic>>[];
    final text = StringBuffer();
    final expected = <int>[];
    for (var section = 0; section < 100; section++) {
      expected.add(text.length);
      final title = 'Sección $section';
      delta.add({'insert': title});
      delta.add({
        'insert': '\n',
        'attributes': {'header': 2}
      });
      text.writeln(title);
      final body = 'İ 🎭 ${List.filled(1000, 'cuervo').join(' ')}\n';
      delta.add({'insert': body});
      text.write(body);
    }
    final clock = Stopwatch()..start();
    final outline = atelierDocumentOutline(delta);
    final outlineMs = clock.elapsedMicroseconds / 1000;
    clock.reset();
    final body = text.toString();
    final matches = atelierFindOccurrences(body, 'CUERVO');
    final searchMs = clock.elapsedMicroseconds / 1000;
    expect(outline.map((item) => item.offset).toList(), expected);
    expect(matches.length, 100000);
    expect(body.substring(matches.first, matches.first + 6), 'cuervo');
    expect(body.substring(matches.last, matches.last + 6), 'cuervo');
    // Diagnostic measurement, no hardware-dependent pass/fail threshold.
    // ignore: avoid_print
    print(
        '100000 words: outline ${outlineMs.toStringAsFixed(1)} ms, search ${searchMs.toStringAsFixed(1)} ms');
  });
}
