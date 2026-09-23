class AtelierTextAnchor {
  final int start;
  final String quote;
  final String before;
  final String after;
  const AtelierTextAnchor(
      {required this.start,
      required this.quote,
      this.before = '',
      this.after = ''});

  factory AtelierTextAnchor.capture(String text, int start, int end) {
    final a = start.clamp(0, text.length);
    final b = end.clamp(a, text.length);
    return AtelierTextAnchor(
        start: a,
        quote: text.substring(a, b),
        before: text.substring((a - 32).clamp(0, a), a),
        after: text.substring(b, (b + 32).clamp(b, text.length)));
  }

  factory AtelierTextAnchor.fromMap(Map map) => AtelierTextAnchor(
      start: (map['start'] as num?)?.toInt() ?? 0,
      quote: map['quote'] as String? ?? '',
      before: map['before'] as String? ?? '',
      after: map['after'] as String? ?? '');
  Map<String, dynamic> toMap() => {
        'start': start,
        'quote': quote,
        'before': before,
        'after': after,
        'format': 'quill-plain-v1'
      };

  /// Nunca aplica una sugerencia a una coincidencia ambigua.
  int? locate(String text) {
    if (quote.isEmpty) return null;
    bool contextMatches(int at) =>
        (before.isEmpty || text.substring(0, at).endsWith(before)) &&
        (after.isEmpty || text.substring(at + quote.length).startsWith(after));
    final candidates = <int>[];
    var at = text.indexOf(quote);
    while (at >= 0) {
      candidates.add(at);
      at = text.indexOf(quote, at + 1);
    }
    if (candidates.length == 1) return candidates.single;
    final contextual = candidates.where(contextMatches).toList();
    return contextual.length == 1 ? contextual.single : null;
  }
}

class AtelierComment {
  final String id;
  final String? parentId;
  final String author;
  final String body;
  final String kind;
  final String status;
  final Map<String, dynamic> anchor;
  final DateTime createdAt;
  const AtelierComment(
      {required this.id,
      this.parentId,
      required this.author,
      required this.body,
      required this.kind,
      required this.status,
      required this.anchor,
      required this.createdAt});
  factory AtelierComment.fromMap(Map<String, dynamic> map) => AtelierComment(
      id: map['id'] as String,
      parentId: map['parent_id'] as String?,
      author: (map['profiles'] as Map?)?['display_name'] as String? ??
          'Colaborador',
      body: map['body'] as String,
      kind: map['kind'] as String,
      status: map['status'] as String,
      anchor: Map<String, dynamic>.from(map['anchor'] as Map? ?? {}),
      createdAt: DateTime.parse(map['created_at'] as String));
}
