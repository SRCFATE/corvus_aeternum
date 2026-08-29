import 'package:corvus_aeternum/features/forums/forum_detail_page.dart';
import 'package:corvus_aeternum/features/forums/forum_thread_page.dart';
import 'package:corvus_aeternum/features/forums/forums_page.dart';
import 'package:corvus_aeternum/models/fan_forum.dart';
import 'package:corvus_aeternum/services/fan_forum_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forum model parses relations and active membership', () {
    final forum = FanForum.fromMap({
      'id': 'forum-1',
      'owner_id': 'author-1',
      'name': 'Lectores del Códice',
      'description': 'Una comunidad privada.',
      'guidelines': 'Respeto ante todo.',
      'join_policy': 'request',
      'is_discoverable': true,
      'status': 'active',
      'accent_hex': '#D13B42',
      'members_count': 12,
      'threads_count': 4,
      'last_activity_at': '2026-08-22T16:00:00.000Z',
      'created_at': '2026-08-20T16:00:00.000Z',
      'owner': {
        'id': 'author-1',
        'username': 'autora',
        'display_name': 'Autora Corvus',
      },
      'linked_work': {
        'id': 'work-1',
        'title': 'Códice del caos',
        'cover_url': 'https://example.com/cover.jpg',
      },
    }).withMembership(_membership(role: 'moderator'));

    expect(forum.owner?.displayName, 'Autora Corvus');
    expect(forum.linkedWork?.title, 'Códice del caos');
    expect(forum.canRead, isTrue);
    expect(forum.canModerate, isTrue);
    expect(forum.accentColor, const Color(0xFFD13B42));
  });

  testWidgets('forum directory stays usable on mobile', (tester) async {
    final forum = _forum(
      membership: _membership(status: 'invited'),
    );
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      ForumsPage(
        service: _DirectoryService([forum]),
      ),
    );

    expect(find.text('Foros privados de autores'), findsOneWidget);
    expect(find.text('Lectores del Códice'), findsOneWidget);
    expect(find.text('Invitación pendiente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner sees requests and community agreements', (tester) async {
    final ownerForum = _forum(
      membership: _membership(role: 'owner'),
    );
    final pending = _membership(
      profileId: 'fan-2',
      status: 'pending',
      profile: const ForumProfileSummary(
        id: 'fan-2',
        username: 'lectora',
        displayName: 'Lectora Nocturna',
      ),
    );
    await _pumpAtSize(
      tester,
      const Size(1100, 900),
      ForumDetailPage(
        forumId: ownerForum.id,
        service: _DetailService(ownerForum, members: [pending]),
      ),
    );

    expect(find.text('ACUERDOS DE CONVIVENCIA'), findsOneWidget);
    expect(find.text('Gestión de la comunidad'), findsOneWidget);
    await tester.tap(find.text('Gestión de la comunidad'));
    await tester.pumpAndSettle();
    expect(find.text('Lectora Nocturna'), findsOneWidget);
    expect(find.byTooltip('Aprobar'), findsOneWidget);
    expect(find.byTooltip('Rechazar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member reads a thread and gets Markdown reply preview', (
    tester,
  ) async {
    final forum = _forum(membership: _membership());
    final thread = _thread();
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      ForumThreadPage(
        forumId: forum.id,
        threadId: thread.id,
        service: _ThreadService(
          forum: forum,
          thread: thread,
          replies: [_reply()],
        ),
      ),
    );

    expect(find.text('El símbolo del capítulo'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Tu respuesta'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      '**Coincido** con esta lectura.',
    );
    await tester.pump();
    expect(find.text('VISTA PREVIA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DirectoryService extends FanForumService {
  final List<FanForum> forums;

  _DirectoryService(this.forums);

  @override
  Future<List<FanForum>> getForums() async => forums;

  @override
  Future<bool> canCreateForum() async => true;
}

class _DetailService extends FanForumService {
  final FanForum forum;
  final List<FanForumMembership> members;

  _DetailService(this.forum, {this.members = const []});

  @override
  Future<FanForum?> getForum(String forumId) async => forum;

  @override
  Future<List<FanForumThread>> getThreads(String forumId) async => const [];

  @override
  Future<List<FanForumMembership>> getMembers(String forumId) async => members;
}

class _ThreadService extends FanForumService {
  final FanForum forum;
  final FanForumThread thread;
  final List<FanForumReply> replies;

  _ThreadService({
    required this.forum,
    required this.thread,
    required this.replies,
  });

  @override
  Future<FanForum?> getForum(String forumId) async => forum;

  @override
  Future<FanForumThread?> getThread(String threadId) async => thread;

  @override
  Future<List<FanForumReply>> getReplies(String threadId) async => replies;
}

FanForum _forum({FanForumMembership? membership}) {
  final now = DateTime.utc(2026, 8, 22, 16);
  return FanForum(
    id: 'forum-1',
    ownerId: 'author-1',
    linkedWorkId: 'work-1',
    name: 'Lectores del Códice',
    description: 'Un círculo para hablar de símbolos, escenas y teorías.',
    guidelines: '**Respeto** entre lectores. Evita revelar finales sin aviso.',
    joinPolicy: 'request',
    isDiscoverable: true,
    status: 'active',
    accentHex: '#D13B42',
    membersCount: 18,
    threadsCount: 3,
    lastActivityAt: now,
    createdAt: now,
    owner: const ForumProfileSummary(
      id: 'author-1',
      username: 'autora',
      displayName: 'Autora Corvus',
    ),
    linkedWork: const ForumWorkSummary(
      id: 'work-1',
      title: 'Códice del caos',
    ),
    myMembership: membership,
  );
}

FanForumMembership _membership({
  String profileId = 'fan-1',
  String role = 'member',
  String status = 'active',
  ForumProfileSummary? profile,
}) {
  return FanForumMembership(
    forumId: 'forum-1',
    profileId: profileId,
    role: role,
    status: status,
    joinedAt: status == 'active' ? DateTime.utc(2026, 8, 22) : null,
    profile: profile,
  );
}

FanForumThread _thread() {
  return FanForumThread(
    id: 'thread-1',
    forumId: 'forum-1',
    authorId: 'author-1',
    title: 'El símbolo del capítulo',
    body: 'Creo que **la llave roja** anticipa el desenlace.',
    isPinned: true,
    isLocked: false,
    repliesCount: 1,
    lastActivityAt: DateTime.utc(2026, 8, 22, 17),
    createdAt: DateTime.utc(2026, 8, 22, 16),
    author: const ForumProfileSummary(
      id: 'author-1',
      username: 'autora',
      displayName: 'Autora Corvus',
    ),
  );
}

FanForumReply _reply() {
  return FanForumReply(
    id: 'reply-1',
    threadId: 'thread-1',
    forumId: 'forum-1',
    authorId: 'fan-2',
    body: 'También aparece en la portada.',
    createdAt: DateTime.utc(2026, 8, 22, 17),
    author: const ForumProfileSummary(
      id: 'fan-2',
      username: 'lectora',
      displayName: 'Lectora Nocturna',
    ),
  );
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}
