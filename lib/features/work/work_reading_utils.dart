// Shared utilities for work reading functionality

class WorkChapter {
  final String title;
  final String content;
  const WorkChapter({required this.title, required this.content});

  String get preview {
    final trimmed = _readingPlainText(content);
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 140) return trimmed;
    final cut = trimmed.substring(0, 140);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > 80 ? cut.substring(0, lastSpace) : cut}…';
  }

  int get wordCount {
    final visible = _readingPlainText(content);
    if (visible.isEmpty) return 0;
    return visible.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
}

List<WorkChapter> parseWorkChapters(String text) {
  if (text.trim().isEmpty) return [];

  final boundedHeaders = _corvusChapterHeader.allMatches(text).toList();
  if (boundedHeaders.isNotEmpty) {
    return _parseCorvusChapters(text, boundedHeaders);
  }

  final markdownHeading = RegExp(r'^#\s+.+', multiLine: true).hasMatch(text)
      ? r'#\s+.+'
      : r'#+\s+.+';
  final headerRx = RegExp(
    '^(?:$markdownHeading|'
    r'[Cc]apítulo\s+\S.*|[Cc]ap\.\s*\d+.*|[Pp]arte\s+\S.*|[Aa]cto\s+\S.*)',
    multiLine: true,
  );

  final matches = headerRx.allMatches(text).toList();

  if (matches.isEmpty) {
    return [WorkChapter(title: '', content: text.trim())];
  }

  final chapters = <WorkChapter>[];
  int lastEnd = 0;
  String? lastTitle;

  for (final m in matches) {
    if (lastTitle != null) {
      chapters.add(WorkChapter(
        title: lastTitle,
        content: text.substring(lastEnd, m.start).trim(),
      ));
    } else if (m.start > 0) {
      final pre = text.substring(0, m.start).trim();
      if (pre.isNotEmpty) {
        chapters.add(WorkChapter(title: 'Prólogo', content: pre));
      }
    }
    lastTitle = m.group(0)!.replaceAll(RegExp(r'^#+\s*'), '').trim();
    lastEnd = m.end;
  }
  if (lastTitle != null) {
    chapters.add(
        WorkChapter(title: lastTitle, content: text.substring(lastEnd).trim()));
  }

  return chapters;
}

final _corvusChapterHeader = RegExp(
  r'^<!--[ \t]*corvus-chapter[ \t]*-->[ \t]*\r?\n#[ \t]+([^\r\n]+?)[ \t]*$',
  multiLine: true,
);

List<WorkChapter> _parseCorvusChapters(
  String text,
  List<RegExpMatch> headers,
) {
  final chapters = <WorkChapter>[];
  final preface = text.substring(0, headers.first.start).trim();
  if (_readingPlainText(preface).isNotEmpty) {
    chapters.add(WorkChapter(title: 'Prólogo', content: preface));
  }

  for (var index = 0; index < headers.length; index++) {
    final header = headers[index];
    final end =
        index + 1 < headers.length ? headers[index + 1].start : text.length;
    chapters.add(WorkChapter(
      title: header.group(1)!.trim(),
      content: text.substring(header.end, end).trim(),
    ));
  }
  return chapters;
}

String _readingPlainText(String source) {
  var value = source
      .replaceAll(
        RegExp(
          r'^<!--[ \t]*corvus-(?:align:(?:left|right|center|justify)|chapter)[ \t]*-->[ \t]*$',
          multiLine: true,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'^[ \t]*(?:\*{3,}|\* \* \*|-{3,}|- - -|_{3,}|_ _ _|⁂)[ \t]*$',
          multiLine: true,
        ),
        '',
      )
      .replaceAllMapped(
        RegExp(r'\[([^\]\n]+)\]\([^)\n]+\)'),
        (match) => match.group(1)!,
      )
      .replaceAllMapped(
        RegExp(r'\[\[([^\]\n]+)\]\]'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'</?u>'), '')
      .replaceAll(RegExp(r'^[ \t]*#{1,6}[ \t]+', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*>[ \t]+', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*[-*][ \t]+', multiLine: true), '')
      .replaceAll(RegExp(r'[*_~`]'), '');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return value;
}

int estimateReadingMinutes(List<WorkChapter> chapters) {
  final totalWords = chapters.fold<int>(0, (sum, c) => sum + c.wordCount);
  final minutes = (totalWords / 250).ceil();
  return minutes < 1 ? 1 : minutes;
}

String formatReadingTime(List<WorkChapter> chapters) {
  final min = estimateReadingMinutes(chapters);
  if (min < 60) return '~$min min de lectura';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '~${h}h de lectura' : '~${h}h ${m}min de lectura';
}
