import 'dart:convert';
import 'package:corvus_aeternum/services/atelier_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('lost first acknowledgement retries the same id without overwriting',
      () async {
    Map<String, dynamic>? stored;
    var insertions = 0;
    final transport = MockClient((request) async {
      if (request.method == 'POST') {
        insertions++;
        if (stored == null) {
          stored = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          throw http.ClientException('Response lost');
        }
        return http.Response(
            jsonEncode({'code': '23505', 'message': 'duplicate key'}), 409,
            headers: {'content-type': 'application/json'},
            reasonPhrase: 'Conflict',
            request: request);
      }
      expect(request.method, 'GET');
      expect(request.url.queryParameters['id'], 'eq.stable-id');
      expect(request.url.queryParameters['profile_id'], 'eq.owner');
      expect(request.url.queryParameters['project_id'], 'eq.project');
      return http.Response(jsonEncode([stored]), 200,
          headers: {'content-type': 'application/json'}, request: request);
    });
    final client = SupabaseClient('https://example.invalid', 'test-key',
        httpClient: transport);
    final service = AtelierService(client: client);
    Future<dynamic> create() => service.createNode(
            nodeId: 'stable-id',
            profileId: 'owner',
            projectId: 'project',
            kind: 'chapter',
            title: 'Primero',
            body: 'Mi texto',
            metadata: {
              'rich_text_delta': [
                {'insert': 'Mi texto\n'}
              ]
            });
    await expectLater(create(), throwsA(anything));
    expect((await create()).body, 'Mi texto');
    expect(insertions, 2);
    // Another session's edit must produce a comparison, never an upsert.
    stored!['body'] = 'Edición posterior';
    await expectLater(
        create(),
        throwsA(isA<AtelierConflictException>().having(
            (e) => e.remote?.body, 'remote body', 'Edición posterior')));
    expect(stored!['body'], 'Edición posterior');
    await client.dispose();
  });
}
