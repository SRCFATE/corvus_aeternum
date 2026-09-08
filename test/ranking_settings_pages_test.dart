import 'package:corvus_aeternum/features/ranking/ranking_page.dart';
import 'package:corvus_aeternum/features/settings/settings_page.dart';
import 'package:corvus_aeternum/features/profile/edit_profile_page.dart';
import 'package:corvus_aeternum/models/artist_ranking.dart';
import 'package:corvus_aeternum/models/user_profile.dart';
import 'package:corvus_aeternum/providers/app_preferences_provider.dart';
import 'package:corvus_aeternum/providers/auth_provider.dart';
import 'package:corvus_aeternum/providers/conspiration_provider.dart';
import 'package:corvus_aeternum/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RankingService extends ProfileService {
  final List<ArtistRankingEntry> entries;

  _RankingService(this.entries);

  @override
  Future<List<ArtistRankingEntry>> getArtistRanking({
    String? discipline,
    int limit = 250,
  }) async {
    if (discipline == null) return entries;
    final filtered = entries
        .map((entry) => entry.profile)
        .where((profile) => profile.disciplines.contains(discipline));
    return ArtistRankingEntry.rank(filtered);
  }
}

void main() {
  UserProfile profile(int index) {
    final now = DateTime(2026);
    return UserProfile(
      id: '$index',
      username: 'autor_$index',
      displayName: 'Autor $index',
      bio: 'Trayectoria de prueba',
      role: 'artist',
      isArtistVerified: index == 1,
      isBanned: false,
      followersCount: 100 - index,
      followingCount: 2,
      worksCount: 12 - index,
      collectionsCount: 3,
      totalLikesReceived: 50 - index,
      disciplines: const ['Literatura'],
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget providers(
    Widget child, {
    AppPreferencesProvider? preferences,
    AuthProvider? auth,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => auth ?? AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConspirationProvider()),
        ChangeNotifierProvider(
          create: (_) => preferences ?? AppPreferencesProvider(),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: child,
      ),
    );
  }

  testWidgets('ranking conserva podio y clasificación en móvil',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entries = ArtistRankingEntry.rank([
      for (var index = 1; index <= 5; index++) profile(index),
    ]);
    await tester.pumpWidget(
      providers(RankingPage(service: _RankingService(entries))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Índice Aeternum'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('CLASIFICACIÓN COMPLETA'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CLASIFICACIÓN COMPLETA'), findsOneWidget);
    expect(find.text('Autor 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configuración es legible y sus preferencias son reales',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferencesProvider();

    await tester.pumpWidget(
      providers(const SettingsPage(), preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configuración'), findsOneWidget);
    expect(find.text('Reducir movimiento'), findsOneWidget);
    expect(find.text('Contraste reforzado'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Reducir movimiento'));
    await tester.pump();
    expect(preferences.reduceMotion, isTrue);
  });

  testWidgets('la ficha de edición no desborda en móvil', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider()..updateProfile(profile(1));

    await tester.pumpWidget(
      providers(const EditProfilePage(), auth: auth),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perfil editorial'), findsOneWidget);
    expect(find.text('Edita tu firma'), findsOneWidget);
    expect(find.text('Ficha pública'.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
