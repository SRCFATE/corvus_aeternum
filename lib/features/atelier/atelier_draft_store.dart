import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Borradores separados por cuenta, proyecto y documento. Nunca se borran
/// hasta que el servidor confirma exactamente la revisión enviada.
class AtelierDraftStore {
  Future<void> _queue = Future.value();

  String key(String profileId, String projectId, String documentId) =>
      'corvus.draft.v1.${Uri.encodeComponent(profileId)}.'
      '${Uri.encodeComponent(projectId)}.${Uri.encodeComponent(documentId)}';

  Future<Map<String, dynamic>?> read(String key) async {
    await _queue;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> write(String key, Map<String, dynamic> value) {
    // Copiar antes del await: el editor puede seguir cambiando.
    final encoded = jsonEncode(value);
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, encoded)) {
        throw StateError('No se pudo conservar el borrador local.');
      }
    });
  }

  Future<List<({String key, Map<String, dynamic> draft})>> pendingNew(
      String profileId, String projectId, String kind) async {
    await _queue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final legacy = key(profileId, projectId, 'new-$kind');
    final pending = <({String key, Map<String, dynamic> draft})>[];
    for (final candidate in prefs.getKeys()) {
      if (candidate != legacy && !candidate.startsWith('$legacy-')) continue;
      try {
        final value = prefs.getString(candidate);
        if (value != null) {
          pending.add((
            key: candidate,
            draft: Map<String, dynamic>.from(jsonDecode(value) as Map)
          ));
        }
      } catch (_) {/* An unreadable backup stays on disk. */}
    }
    pending.sort(
        (a, b) => '${b.draft['saved_at']}'.compareTo('${a.draft['saved_at']}'));
    return pending;
  }

  Future<void> remove(String key) => _enqueue(() async {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.remove(key)) {
          throw StateError('No se pudo retirar el borrador local.');
        }
      });

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _queue.then((_) => action());
    _queue = operation.catchError((Object _) {});
    return operation;
  }
}
