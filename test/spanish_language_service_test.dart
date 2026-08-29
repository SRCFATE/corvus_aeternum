import 'package:corvus_aeternum/services/spanish_language_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = SpanishLanguageService();

  test('detects accents, repeated words and punctuation spacing', () {
    final suggestions = service.analyze('Tambien  tambien ,brilla.');

    expect(
      suggestions.where((item) => item.kind == LanguageSuggestionKind.spelling),
      hasLength(2),
    );
    expect(
      suggestions.any((item) => item.kind == LanguageSuggestionKind.repetition),
      isTrue,
    );
    expect(
      suggestions
          .where((item) => item.kind == LanguageSuggestionKind.typography)
          .length,
      greaterThanOrEqualTo(2),
    );

    final accent = suggestions.firstWhere((item) => item.found == 'Tambien');
    expect(service.apply('Tambien', accent, accent.replacements.first),
        'Tambi\u00e9n');
  });

  test('searches dictionary by headword and synonym', () {
    expect(service.searchThesaurus('misterio').first.word, 'misterio');
    expect(
      service
          .searchThesaurus('resplandecer')
          .any((entry) => entry.word == 'brillar'),
      isTrue,
    );
  });
}
