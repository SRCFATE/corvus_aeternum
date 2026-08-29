// Shared utilities for work reading functionality

class WorkChapter {
  final String title;
  final String content;
  const WorkChapter({required this.title, required this.content});

  String get preview {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 140) return trimmed;
    final cut = trimmed.substring(0, 140);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > 80 ? cut.substring(0, lastSpace) : cut}…';
  }

  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
}

List<WorkChapter> parseWorkChapters(String text) {
  if (text.trim().isEmpty) return [];

  final headerRx = RegExp(
    r'^(#+\s+.+|[Cc]apítulo\s+\S.*|[Cc]ap\.\s*\d+.*|[Pp]arte\s+\S.*|[Aa]cto\s+\S.*)',
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
      if (pre.isNotEmpty) chapters.add(WorkChapter(title: 'Prólogo', content: pre));
    }
    lastTitle = m.group(0)!.replaceAll(RegExp(r'^#+\s*'), '').trim();
    lastEnd = m.end;
  }
  if (lastTitle != null) {
    chapters.add(WorkChapter(title: lastTitle, content: text.substring(lastEnd).trim()));
  }

  return chapters;
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
