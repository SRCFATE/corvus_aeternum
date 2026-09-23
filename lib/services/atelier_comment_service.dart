import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/atelier_comment.dart';

class AtelierCommentService {
  static int _watchId = 0;

  /// Payloads are deliberately discarded: every refresh reads through RLS.
  /// Periodic reconciliation also catches deletions and revoked access, whose
  /// events may no longer be visible to the subscriber.
  Stream<void> watchChanges({String? projectId}) {
    late final StreamController<void> events;
    RealtimeChannel? channel;
    Timer? reconciliation;
    void refresh() {
      if (!events.isClosed) events.add(null);
    }

    events = StreamController<void>(onListen: () {
      reconciliation =
          Timer.periodic(const Duration(minutes: 1), (_) => refresh());
      try {
        final filter = projectId == null
            ? null
            : PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'project_id',
                value: projectId);
        channel = supabase.channel('atelier-reviews-${_watchId++}')
          ..onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'atelier_comments',
              filter: filter,
              callback: (_) => refresh())
          ..onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'atelier_comments',
              filter: filter,
              callback: (_) => refresh())
          ..subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed) refresh();
          });
      } catch (_) {
        // Offline/realtime unavailable: ordinary reads can still recover.
      }
    }, onCancel: () async {
      reconciliation?.cancel();
      if (channel != null) {
        try {
          await supabase.removeChannel(channel!);
        } catch (_) {
          // Disposal must remain safe when the transport is already closed.
        }
      }
    });
    return events.stream;
  }

  Future<List<String>> capabilities(String projectId) async {
    final data = await supabase.rpc('atelier_project_capabilities',
        params: {'p_project_id': projectId});
    return List<String>.from(data as List);
  }

  Future<List<AtelierComment>> load(String projectId, String nodeId) async {
    final rows = await supabase
        .from('atelier_comments')
        .select('*,profiles!atelier_comments_profile_id_fkey(display_name)')
        .eq('project_id', projectId)
        .eq('node_id', nodeId)
        .neq('status', 'deleted')
        .order('created_at');
    return rows.map((row) => AtelierComment.fromMap(row)).toList();
  }

  Future<void> add(
      {required String projectId,
      required String nodeId,
      required String profileId,
      required String body,
      required Map<String, dynamic> anchor,
      bool suggestion = false,
      String? parentId}) async {
    await supabase.from('atelier_comments').insert({
      'project_id': projectId,
      'node_id': nodeId,
      'profile_id': profileId,
      'body': body.trim(),
      'anchor': anchor,
      'kind': suggestion ? 'suggestion' : 'comment',
      if (parentId != null) 'parent_id': parentId
    });
  }

  Future<void> resolve(
      String projectId, AtelierComment comment, String profileId,
      {String resolution = 'resolved'}) async {
    await supabase
        .from('atelier_comments')
        .update({
          'status': 'resolved',
          'resolved_by': profileId,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'anchor': {...comment.anchor, 'resolution': resolution}
        })
        .eq('id', comment.id)
        .eq('project_id', projectId)
        .select()
        .single();
  }
}
