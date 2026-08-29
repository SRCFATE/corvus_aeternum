import 'package:corvus_aeternum/features/work/work_reading_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseWorkChapters', () {
    test('returns one untitled chapter when no headers are present', () {
      final chapters = parseWorkChapters('A short standalone text.');

      expect(chapters, hasLength(1));
      expect(chapters.first.title, isEmpty);
      expect(chapters.first.content, 'A short standalone text.');
    });

    test('splits markdown headings and keeps intro text as prologue', () {
      final chapters = parseWorkChapters(
          'Intro\n\n# Chapter One\nBody one\n# Chapter Two\nBody two');

      expect(chapters, hasLength(3));
      expect(chapters[0].content, 'Intro');
      expect(chapters[1].title, 'Chapter One');
      expect(chapters[1].content, 'Body one');
      expect(chapters[2].title, 'Chapter Two');
      expect(chapters[2].content, 'Body two');
    });
  });

  group('WorkChapter', () {
    test('counts words across whitespace', () {
      const chapter = WorkChapter(title: 'I', content: 'one\ntwo   three');

      expect(chapter.wordCount, 3);
    });

    test('trims preview on a word boundary', () {
      final chapter = WorkChapter(
        title: 'Long',
        content: List.filled(40, 'word').join(' '),
      );

      expect(chapter.preview.length, lessThanOrEqualTo(141));
      expect(chapter.preview, endsWith('\u2026'));
    });
  });

  test('formatReadingTime formats short and long works', () {
    final short = [
      WorkChapter(title: '', content: List.filled(20, 'word').join(' '))
    ];
    final long = [
      WorkChapter(title: '', content: List.filled(15000, 'word').join(' '))
    ];

    expect(formatReadingTime(short), '~1 min de lectura');
    expect(formatReadingTime(long), '~1h de lectura');
  });
}
