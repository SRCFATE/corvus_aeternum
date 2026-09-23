class AtelierHeading {
  final String title;
  final int level;
  final int offset;
  const AtelierHeading(this.title, this.level, this.offset);
}

List<AtelierHeading> atelierDocumentOutline(List<Map<String, dynamic>> delta) {
  final result = <AtelierHeading>[];
  var offset = 0;
  var lineStart = 0;
  final text = StringBuffer();
  for (final operation in delta) {
    final insert = operation['insert'];
    if (insert is! String) {
      offset++;
      continue;
    }
    for (var i = 0; i < insert.length; i++) {
      if (insert[i] == '\n') {
        final attrs = operation['attributes'];
        final level = attrs is Map ? attrs['header'] : null;
        if (level is int) {
          final title = text.toString().trim();
          result.add(AtelierHeading(
              title.isEmpty ? 'Sección sin título' : title, level, lineStart));
        }
        text.clear();
        lineStart = offset + 1;
      } else {
        text.write(insert[i]);
      }
      offset++;
    }
  }
  return result;
}

List<int> atelierFindOccurrences(String text, String query) {
  if (query.trim().isEmpty) return const [];
  // Match the original text: case conversion can change UTF-16 length (İ),
  // which would shift every subsequent highlight and navigation offset.
  return RegExp(RegExp.escape(query), caseSensitive: false, unicode: true)
      .allMatches(text)
      .map((match) => match.start)
      .toList();
}
