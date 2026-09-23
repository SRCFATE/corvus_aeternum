import '../../models/atelier_models.dart';

class AtelierReferenceRepair {
  final int offset;
  final String source;
  final String? explicitLabel;
  final List<AtelierNode> candidates;
  final bool renamed;
  const AtelierReferenceRepair(
      {required this.offset,
      required this.source,
      required this.candidates,
      this.explicitLabel,
      this.renamed = false});
  String replacement(AtelierNode target) => explicitLabel ?? target.title;
}

bool atelierNameMatches(AtelierNode node, String name) {
  final query = name.trim().toLowerCase();
  if (node.title.trim().toLowerCase() == query) return true;
  return atelierReferenceNames(node)
      .any((alias) => alias.trim().toLowerCase() == query);
}

Iterable<String> atelierReferenceNames(AtelierNode node) sync* {
  yield node.title;
  final aliases = node.metadata['aliases'];
  if (aliases is List) yield* aliases.whereType<String>();
  if (aliases is String) yield* aliases.split(RegExp(r'[,;\n]'));
  final alias = node.metadata['alias'];
  if (alias is String && alias.trim().isNotEmpty) yield alias;
}

/// Only explicit references are candidates. Casual prose and code are untouched.
List<AtelierReferenceRepair> atelierReferenceRepairs(
    List<Map<String, dynamic>> delta, List<AtelierNode> references) {
  final targets =
      references.where((n) => n.metadata['deleted_at'] == null).toList();
  final text = StringBuffer();
  final blocked = <({int start, int end})>[];
  final links = <({int start, int end, String id, String label})>[];
  var offset = 0;
  var lineStart = 0;
  for (final op in delta) {
    final insert = op['insert'];
    final chunk = insert is String ? insert : '\uFFFC';
    final attrs = op['attributes'] is Map ? op['attributes'] as Map : const {};
    final link = attrs['link'];
    if (attrs['code'] == true || link != null) {
      blocked.add((start: offset, end: offset + chunk.length));
    }
    for (var i = 0; i < chunk.length; i++) {
      if (chunk[i] == '\n') {
        if (attrs['code-block'] != null) {
          blocked.add((start: lineStart, end: offset + i + 1));
        }
        lineStart = offset + i + 1;
      }
    }
    if (insert is String && link is String && link.startsWith('corvus-node:')) {
      final id = link.substring('corvus-node:'.length);
      if (links.isNotEmpty && links.last.end == offset && links.last.id == id) {
        final previous = links.removeLast();
        links.add((
          start: previous.start,
          end: offset + chunk.length,
          id: id,
          label: previous.label + chunk
        ));
      } else {
        links.add(
            (start: offset, end: offset + chunk.length, id: id, label: chunk));
      }
    }
    text.write(chunk);
    offset += chunk.length;
  }
  final plain = text.toString();
  final repairs = <AtelierReferenceRepair>[];
  for (final match
      in RegExp(r'\[\[([^\]\n|]+)(?:\|([^\]\n]+))?\]\]').allMatches(plain)) {
    if ((match.start > 0 && plain[match.start - 1] == '\\') ||
        blocked.any((b) => b.start < match.end && b.end > match.start)) {
      continue;
    }
    repairs.add(AtelierReferenceRepair(
        offset: match.start,
        source: match[0]!,
        explicitLabel: match[2],
        candidates:
            targets.where((n) => atelierNameMatches(n, match[1]!)).toList()));
  }
  for (final link in links) {
    final target = targets.where((n) => n.id == link.id).firstOrNull;
    if (target != null &&
        link.label != target.title &&
        atelierNameMatches(target, link.label)) {
      repairs.add(AtelierReferenceRepair(
          offset: link.start,
          source: link.label,
          candidates: [target],
          renamed: true));
    }
  }
  repairs.sort((a, b) => a.offset.compareTo(b.offset));
  return repairs;
}
