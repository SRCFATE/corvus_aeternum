import 'dart:convert';
import 'dart:math';

/// Validates an export before presenting its summary. The server repeats the
/// validation and owns identifier remapping and the atomic write.
class AtelierProjectImport {
  static const maxBytes = 10 * 1024 * 1024;
  final Map<String, dynamic> payload;
  final String requestId;
  AtelierProjectImport._(this.payload, this.requestId);

  String get title => (payload['project'] as Map)['title'] as String;
  int get nodeCount => (payload['nodes'] as List).length;
  int get relationCount => (payload['relations'] as List).length;
  int get versionCount => (payload['versions'] as List).length;

  factory AtelierProjectImport.parse(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('El archivo supera el límite de 10 MB.');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException(
          'El archivo no es una exportación JSON válida.');
    }
    if (decoded is! Map<String, dynamic> || decoded['project'] is! Map) {
      throw const FormatException('Faltan los datos del proyecto.');
    }
    final project = decoded['project'] as Map;
    if (project['title'] is! String ||
        (project['title'] as String).trim().isEmpty) {
      throw const FormatException('El proyecto necesita un título.');
    }
    for (final entry
        in {'nodes': 2000, 'relations': 10000, 'versions': 1000}.entries) {
      final rows = decoded[entry.key];
      if (rows is! List ||
          rows.length > entry.value ||
          rows.any((row) => row is! Map<String, dynamic>)) {
        throw FormatException(
            'La sección «${entry.key}» falta o no es válida.');
      }
    }
    final ids = <String>{};
    for (final node in decoded['nodes'] as List) {
      final id = node['id'];
      if (id is! String ||
          !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
              .hasMatch(id) ||
          !ids.add(id) ||
          node['title'] is! String ||
          node['body'] is! String ||
          node['kind'] is! String) {
        throw const FormatException(
            'Hay elementos incompletos o identificadores repetidos.');
      }
    }
    for (final relation in decoded['relations'] as List) {
      if (!ids.contains(relation['source_node_id']) ||
          !ids.contains(relation['target_node_id']) ||
          relation['source_node_id'] == relation['target_node_id']) {
        throw const FormatException(
            'Una relación apunta a un elemento que no está en el archivo.');
      }
    }
    // Retained for every retry of this preview, including a lost acknowledgement.
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return AtelierProjectImport._(decoded,
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}');
  }
}
