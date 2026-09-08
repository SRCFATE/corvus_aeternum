import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/profile_service.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/recover_password_page.dart';
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
import '../../features/ranking/ranking_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/conspiracies/conspiracies_registry_page.dart';
import '../../features/glossary/glossary_page.dart';
import '../../features/atelier/atelier_page.dart';
import '../../features/atelier/billing/presentation/billing_center_page.dart';
import '../../features/atelier/billing/presentation/plans_page.dart';
import '../../features/atelier/billing/presentation/workspace_detail_page.dart';
import '../../features/atelier/billing/presentation/workspaces_page.dart';
import 'navigation_coordinator.dart';
import '../../features/insights/insights_page.dart';
import '../../features/planner/planner_page.dart';
import '../../features/arena/arena_page.dart';
import '../../features/forums/forums_page.dart';
import '../../features/forums/create_forum_page.dart';
import '../../features/forums/forum_detail_page.dart';
import '../../features/forums/forum_thread_page.dart';

/// Corvus es abierto para descubrir y consultar, y autenticado para
/// participar. Estas son las rutas que alguien sin sesión puede abrir; las
/// acciones (dar like, guardar, comentar, seguir, publicar) piden sesión
/// dentro de la propia pantalla, sin duplicarla en versión pública.
bool isPublicLocation(String location) {
  const publicRoutes = {
    '/discover',
    '/artists',
    '/arena',
    '/ranking',
    '/challenges',
    // Los planes se consultan sin sesión: quien evalúa Corvus antes de
    // registrarse merece saber lo que cuesta. Contratar sí pide cuenta.
    '/plans',
  };

  if (publicRoutes.contains(location)) return true;

  // El perfil público de un artista es /profile/:username. El perfil propio
  // vive en /profile y su edición en /profile/edit, y ambos piden sesión.
  if (location.startsWith('/profile/') && location != '/profile/edit') {
    return true;
  }

  const publicPrefixes = ['/work/', '/artist/', '/certificate/'];

  return publicPrefixes.any(location.startsWith);
}

/// El destino que el visitante intentaba abrir antes de que le pidiéramos
/// sesión. Solo se acepta una ruta interna: un destino absoluto o
/// protocolo-relativo podría sacar al artista de Corvus tras iniciar sesión.
String? redirectTargetOf(Uri uri) {
  final target = uri.queryParameters['redirect'];

  if (target == null || target.isEmpty) return null;
  if (!target.startsWith('/') || target.startsWith('//')) return null;

  return target;
}

/// La regla de acceso de Corvus, aislada del cliente de Supabase para poder
/// fijarla en pruebas. Devuelve la ruta a la que hay que desviar, o null si
/// la navegación puede seguir.
String? resolveAuthRedirect({
  required bool isAuth,
  required bool hasProfile,
  required String location,
  required Uri uri,
}) {
  final isLogin = location.startsWith('/login');
  final isRegister = location.startsWith('/register');
  final isCreateProfile = location.startsWith('/create-profile');
  final isRecover = location.startsWith('/recover');

  final isAuthRoute = isLogin || isRegister || isCreateProfile || isRecover;

  if (!isAuth) {
    if (isAuthRoute || isPublicLocation(location)) return null;

    // Conserva a dónde iba: sin esto, un enlace compartido se perdería en el
    // login y el visitante acabaría en Descubrir sin saber por qué.
    return '/login?redirect=${Uri.encodeComponent(uri.toString())}';
  }

  if (isLogin || isRegister) {
    return redirectTargetOf(uri) ?? '/discover';
  }

  if (!hasProfile && !isCreateProfile) {
    return '/create-profile';
  }

  if (hasProfile && isCreateProfile) {
    return redirectTargetOf(uri) ?? '/discover';
  }

  return null;
}

/// El tramo autenticado sí necesita saber si el perfil está creado, y esa
/// consulta es asíncrona.
Future<String?> _redirectForSession(
    Session session, GoRouterState state) async {
  final hasProfile =
      await ProfileService().getProfileById(session.user.id) != null;

  return resolveAuthRedirect(
    isAuth: true,
    hasProfile: hasProfile,
    location: state.matchedLocation,
    uri: state.uri,
  );
}

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/discover',
    // Sin `async`: un visitante no tiene perfil que consultar, así que su
    // camino se resuelve en el acto y go_router no espera un Future en cada
    // navegación pública.
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        return resolveAuthRedirect(
          isAuth: false,
          hasProfile: false,
          location: state.matchedLocation,
          uri: state.uri,
        );
      }

      return _redirectForSession(session, state);
    },
    routes: [
      // La raíz es Descubrir, la Home de Corvus, con o sin sesión. El feed
      // personal existe en /feed y no recupera ese papel.
      GoRoute(
        path: '/',
        redirect: (_, __) => '/discover',
      ),
      // Alias semántico del espacio de desafíos.
      GoRoute(
        path: '/challenges',
        redirect: (_, __) => '/arena',
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            LoginPage(redirectTo: redirectTargetOf(state.uri)),
      ),
      GoRoute(
        path: '/register',
        builder: (_, state) =>
            RegisterPage(redirectTo: redirectTargetOf(state.uri)),
      ),
      GoRoute(
        path: '/recover',
        builder: (_, state) => RecoverPasswordPage(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/create-profile',
        builder: (_, state) =>
            CreateProfilePage(redirectTo: redirectTargetOf(state.uri)),
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
            path: '/ranking',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: RankingPage(),
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
          GoRoute(
            path: '/settings',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: SettingsPage(),
            ),
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
      // La comparación de planes vive fuera del shell: es una decisión, no un
      // espacio en el que uno se quede.
      GoRoute(
        path: '/plans',
        builder: (_, state) => PlansPage(
          highlightFeature: state.uri.queryParameters['feature'],
        ),
      ),
      GoRoute(
        path: '/settings/billing',
        builder: (_, state) => BillingCenterPage(
          workspaceId: state.uri.queryParameters['workspace'],
        ),
      ),
      // Los espacios de trabajo viven fuera del shell: administrar un estudio
      // es una tarea, no un sitio donde uno se queda leyendo.
      GoRoute(
        path: '/workspaces',
        builder: (_, __) => const WorkspacesPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) {
              final id = state.pathParameters['id'];
              if (id == null) return const WorkspacesPage();
              return WorkspaceDetailPage(workspaceId: id);
            },
          ),
        ],
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
            if (!profile.isAdmin) return '/discover';

            return null;
          } catch (_) {
            return '/discover';
          }
        },
        builder: (_, __) => const AdminPanelPage(),
      ),
    ],
  );
}
