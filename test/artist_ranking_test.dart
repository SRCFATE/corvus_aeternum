import 'package:corvus_aeternum/models/artist_ranking.dart';
import 'package:corvus_aeternum/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserProfile profile({
    required String username,
    int followers = 0,
    int works = 0,
    int likes = 0,
    int collections = 0,
    bool verified = false,
  }) {
    final now = DateTime(2026);
    return UserProfile(
      id: username,
      username: username,
      displayName: username,
      bio: '',
      role: 'artist',
      isArtistVerified: verified,
      isBanned: false,
      followersCount: followers,
      followingCount: 0,
      worksCount: works,
      collectionsCount: collections,
      totalLikesReceived: likes,
      disciplines: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  test('el índice premia una trayectoria completa', () {
    final onlyAudience = profile(username: 'audiencia', followers: 1000);
    final complete = profile(
      username: 'trayectoria',
      followers: 300,
      works: 24,
      likes: 900,
      collections: 8,
      verified: true,
    );

    expect(
      ArtistRankingEntry.scoreFor(complete),
      greaterThan(ArtistRankingEntry.scoreFor(onlyAudience)),
    );
  });

  test('produce posiciones consecutivas y desempate estable', () {
    final entries = ArtistRankingEntry.rank([
      profile(username: 'zeta', works: 2),
      profile(username: 'alfa', works: 2),
      profile(username: 'primero', works: 12, likes: 20),
    ]);

    expect(entries.map((entry) => entry.position), [1, 2, 3]);
    expect(entries.first.profile.username, 'primero');
    expect(entries[1].profile.username, 'alfa');
    expect(entries[2].profile.username, 'zeta');
  });

  test('asigna círculos con límites conocidos', () {
    expect(
      ArtistRankingEntry.circleFor(149),
      AeternumCircle.iniciado,
    );
    expect(
      ArtistRankingEntry.circleFor(150),
      AeternumCircle.emergente,
    );
    expect(
      ArtistRankingEntry.circleFor(2500),
      AeternumCircle.legendario,
    );
  });
}
