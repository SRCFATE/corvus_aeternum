import 'dart:convert';
import 'package:corvus_aeternum/models/atelier_models.dart';
import 'package:corvus_aeternum/services/atelier_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _project = AtelierProject.fromMap({
  'id': 'project',
  'profile_id': 'author',
  'title': 'Libro',
  'metadata': {'atelier_branch': 'writing', 'publication_work_id': 'work'}
});
final _chapter = AtelierNode.fromMap({
  'id': 'chapter',
  'project_id': 'project',
  'profile_id': 'author',
  'kind': 'chapter',
  'title': 'Entrada',
  'body': 'Texto publicado.',
  'tags': ['narración']
});

void main() {
  test('one atomic request excludes private tags and trashed nodes', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode({'work_id': 'work', 'chapters': 1, 'is_published': false}),
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    final service = AtelierService(client: client);
    await service.preparePublication(project: _project, nodes: [
      _chapter,
      _chapter.copyWith(kind: 'character', tags: ['spoiler privado']),
      _chapter
          .copyWith(tags: ['eliminado'], metadata: {'deleted_at': '2026-09-20'})
    ], relations: [], versions: []);
    expect(requests, hasLength(1));
    expect(
        requests.single.url.path, endsWith('/rpc/atelier_commit_publication'));
    final data = jsonDecode(requests.single.body) as Map;
    expect(data['p_payload']['tags'], ['narración']);
    expect(data['p_payload']['text_body'], contains('Texto publicado.'));
    expect(data['p_publication_snapshot'], hasLength(1));
    expect(data['p_expected_nodes'], hasLength(2));
    expect(data['p_preparing'], isTrue);
    await client.dispose();
  });

  test('stale review is explained and never falls back to partial writes',
      () async {
    var calls = 0;
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      calls++;
      return http.Response(
          jsonEncode({'code': 'P0001', 'message': 'EDITION_CHANGED'}), 400,
          headers: {'content-type': 'application/json'}, request: request);
    }));
    await expectLater(
        AtelierService(client: client).syncPublishedWork(
            project: _project, nodes: [_chapter], relations: [], versions: []),
        throwsA(isA<AtelierPublicationException>().having((e) => e.message,
            'explanation', contains('cambió desde la revisión'))));
    expect(calls, 1);
    await client.dispose();
  });
}
