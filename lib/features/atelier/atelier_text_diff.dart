import 'package:flutter/material.dart';
import '../../shared/widgets/formatted_manuscript_text.dart';

enum EditorialChange { unchanged, added, removed }

class EditorialDiffLine {
  final String text;
  final EditorialChange change;
  const EditorialDiffLine(this.text, this.change);
}

/// Line comparison with bounded memory, including for book-length documents.
List<EditorialDiffLine> compareEditorialText(String before, String after) {
  final a = before.split('\n');
  final b = after.split('\n');
  var prefix = 0;
  while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < a.length - prefix &&
      suffix < b.length - prefix &&
      a[a.length - suffix - 1] == b[b.length - suffix - 1]) {
    suffix++;
  }
  final old = a.sublist(prefix, a.length - suffix);
  final next = b.sublist(prefix, b.length - suffix);
  final result = a
      .take(prefix)
      .map((line) => EditorialDiffLine(line, EditorialChange.unchanged))
      .toList();
  if (old.length * next.length > 160000) {
    result.addAll(
        old.map((line) => EditorialDiffLine(line, EditorialChange.removed)));
    result.addAll(
        next.map((line) => EditorialDiffLine(line, EditorialChange.added)));
  } else {
    final lengths =
        List.generate(old.length + 1, (_) => List.filled(next.length + 1, 0));
    for (var i = old.length - 1; i >= 0; i--) {
      for (var j = next.length - 1; j >= 0; j--) {
        lengths[i][j] = old[i] == next[j]
            ? lengths[i + 1][j + 1] + 1
            : (lengths[i + 1][j] > lengths[i][j + 1]
                ? lengths[i + 1][j]
                : lengths[i][j + 1]);
      }
    }
    var i = 0;
    var j = 0;
    while (i < old.length || j < next.length) {
      if (i < old.length && j < next.length && old[i] == next[j]) {
        result.add(EditorialDiffLine(old[i++], EditorialChange.unchanged));
        j++;
      } else if (j < next.length &&
          (i == old.length || lengths[i][j + 1] > lengths[i + 1][j])) {
        result.add(EditorialDiffLine(next[j++], EditorialChange.added));
      } else {
        result.add(EditorialDiffLine(old[i++], EditorialChange.removed));
      }
    }
  }
  result.addAll(a
      .skip(a.length - suffix)
      .map((line) => EditorialDiffLine(line, EditorialChange.unchanged)));
  return result;
}

class EditorialTextDiff extends StatelessWidget {
  final String before;
  final String after;
  const EditorialTextDiff(
      {super.key, required this.before, required this.after});
  @override
  Widget build(BuildContext context) {
    final changes = compareEditorialText(before, after)
        .where((line) => line.change != EditorialChange.unchanged)
        .toList();
    if (changes.isEmpty) return const Text('Sin cambios en el texto.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final line in changes)
        Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: (line.change == EditorialChange.added
                        ? Colors.green
                        : Colors.red)
                    .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  line.change == EditorialChange.added ? 'Añadido' : 'Retirado',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              FormattedManuscriptText(text: line.text),
            ])),
    ]);
  }
}
