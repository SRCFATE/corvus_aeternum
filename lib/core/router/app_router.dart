import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/profile_service.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/create_profile_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/feed/feed_page.dart';
import '../../features/work/work_chapter_page.dart';
import '../../features/work/work_detail_page.dart';
import '../../features/work/upload_work_page.dart';
import '../../features/discover/discover_page.dart';
import '../../features/collections/collections_page.dart';
import '../../features/collections/collection_detail_page.dart';
import '../../features/collections/create_collection_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/auctions/auctions_page.dart';
import '../../features/auctions/auction_detail_page.dart';
import '../../features/auctions/create_auction_page.dart';
import '../../features/certificates/certificate_detail_page.dart';
import '../../features/certificates/certificates_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/admin/admin_panel_page.dart';
import '../../features/artists/artists_page.dart';
import '../../features/conspiracies/conspiracies_registry_page.dart';
import '../../features/glossary/glossary_page.dart';
import '../../features/atelier/atelier_page.dart';
import 'navigation_coordinator.dart';
import '../../features/insights/insights_page.dart';
import '../../features/planner/planner_page.dart';
import '../../features/arena/arena_page.dart';
import '../../features/forums/forums_page.dart';
import '../../features/forums/create_forum_page.dart';
import '../../features/forums/forum_detail_page.dart';
import '../../features/forums/forum_thread_page.dart';

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/feed',
    redirect: (context, state) async {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final isAuth = session != null;

      final location = state.matchedLocation;

      final isLogin = location.startsWith('/login');
      final isRegister = location.startsWith('/register');
      final isCreateProfile = location.startsWith('/create-profile');
      final isPublicCertificate = location.startsWith('/certificate/');

      final isAuthRoute = isLogin || isRegister || isCreateProfile;

      if (!isAuth) {
        if (isAuthRoute || isPublicCertificate) return null;
        return '/login';
      }

      if (isAuth && (isLogin || isRegister)) {
        return '/feed';
      }

      final hasProfile =
          await ProfileService().getProfileById(session.user.id) != null;

      if (!hasProfile && !isCreateProfile) {
        return '/create-profile';
      }

      if (hasProfile && isCreateProfile) {
        return '/feed';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: '/create-profile',
        builder: (_, __) => const CreateProfilePage(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: FeedPage(),
            ),
          ),
          GoRoute(
            path: '/discover',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: DiscoverPage(),
            ),
          ),
          GoRoute(
            path: '/artists',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ArtistsPage(),
            ),
          ),
          GoRoute(
            path: '/atelier',
            pageBuilder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;

              return NoTransitionPage(
                child: AtelierPage(initialProject: extra),
              );
            },
          ),
          GoRoute(
            path: '/mundiarium',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: AtelierPage(
                initialSection: AtelierInitialSection.mundiarium,
              ),
            ),
          ),
          GoRoute(
            path: '/archive',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: AtelierPage(
                initialSection: AtelierInitialSection.archive,
              ),
            ),
          ),
          GoRoute(
            path: '/auctions',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: AuctionsPage(),
            ),
          ),
          GoRoute(
            path: '/collections',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: CollectionsPage(),
            ),
          ),
          GoRoute(
            path: '/certificates',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: CertificatesPage(),
            ),
          ),
          GoRoute(
            path: '/insights',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: InsightsPage(),
            ),
          ),
          GoRoute(
            path: '/planner',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlannerPage(),
            ),
          ),
          GoRoute(
            path: '/arena',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ArenaPage(),
            ),
          ),
          GoRoute(
            path: '/glossary',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: GlossaryPage(),
            ),
          ),
          GoRoute(
            path: '/forums',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ForumsPage(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, __) => const CreateForumPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) {
                  final forumId = state.pathParameters['id'];
                  if (forumId == null) return const ForumsPage();
                  return ForumDetailPage(forumId: forumId);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) {
                      final forumId = state.pathParameters['id'];
                      if (forumId == null) return const ForumsPage();
                      return CreateForumPage(forumId: forumId);
                    },
                  ),
                  GoRoute(
                    path: 'thread/:threadId',
                    builder: (_, state) {
                      final forumId = state.pathParameters['id'];
                      final threadId = state.pathParameters['threadId'];
                      if (forumId == null || threadId == null) {
                        return const ForumsPage();
                      }
                      return ForumThreadPage(
                        forumId: forumId,
                        threadId: threadId,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ProfilePage(),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, __) => const EditProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/work/:id',
        builder: (_, state) {
          final workId = state.pathParameters['id'];
          if (workId == null) return const FeedPage();
          return WorkDetailPage(workId: workId);
        },
        routes: [
          GoRoute(
            path: 'chapter/:chapterIndex',
            builder: (_, state) {
              final workId = state.pathParameters['id']!;
              final idx =
                  int.tryParse(state.pathParameters['chapterIndex'] ?? '0') ??
                      0;
              return WorkChapterPage(workId: workId, initialChapter: idx);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/upload',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;

          return UploadWorkPage(
            initialDiscipline: extra?['discipline'] as String?,
            initialSubdiscipline: extra?['subdiscipline'] as String?,
            initialDraftId: extra?['draftId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/collection/create',
        builder: (_, __) => const CreateCollectionPage(),
      ),
      GoRoute(
        path: '/collection/:id',
        builder: (_, state) {
          final collectionId = state.pathParameters['id'];
          if (collectionId == null) return const CollectionsPage();
          return CollectionDetailPage(collectionId: collectionId);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) {
              final collectionId = state.pathParameters['id'];
              return CreateCollectionPage(collectionId: collectionId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/auction/create',
        builder: (_, __) => const CreateAuctionPage(),
      ),
      GoRoute(
        path: '/certificate/:number',
        builder: (_, state) {
          final number = state.pathParameters['number'];
          if (number == null) return const CertificatesPage();
          return CertificateDetailPage(certificateNumber: number);
        },
      ),
      GoRoute(
        path: '/auction/:id',
        builder: (_, state) {
          final auctionId = state.pathParameters['id'];
          if (auctionId == null) return const AuctionsPage();
          return AuctionDetailPage(auctionId: auctionId);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) {
              final auctionId = state.pathParameters['id'];
              return CreateAuctionPage(auctionId: auctionId);
            },
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/profile/:username',
        builder: (_, state) {
          final username = state.pathParameters['username'];
          if (username == null) return const FeedPage();
          return ProfilePage(username: username);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/artist/:id',
        builder: (_, state) {
          final userId = state.pathParameters['id'];

          if (userId == null || userId.isEmpty) {
            return const ArtistsPage();
          }

          return ProfilePage(userId: userId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/conspiracies',
        builder: (_, __) => const HomeShell(
          child: ConspiraciesRegistryPage(),
        ),
      ),
      GoRoute(
        path: '/admin',
        redirect: (context, state) async {
          final session = Supabase.instance.client.auth.currentSession;

          if (session == null) return '/login';

          try {
            final profile =
                await ProfileService().getProfileById(session.user.id);

            if (profile == null) return '/create-profile';
            if (!profile.isAdmin) return '/feed';

            return null;
          } catch (_) {
            return '/feed';
          }
        },
        builder: (_, __) => const AdminPanelPage(),
      ),
    ],
  );
}
