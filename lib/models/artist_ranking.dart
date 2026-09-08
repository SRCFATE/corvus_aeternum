import 'dart:math' as math;

import 'user_profile.dart';

/// Los círculos editoriales del Índice Aeternum.
///
/// No son un rol ni un permiso: condensan trayectoria y recepción pública en
/// una etiqueta legible. El valor exacto siempre se conserva en [score].
enum AeternumCircle {
  legendario,
  magistral,
  consagrado,
  emergente,
  iniciado,
}

extension AeternumCircleLabel on AeternumCircle {
  String get label => switch (this) {
        AeternumCircle.legendario => 'Círculo legendario',
        AeternumCircle.magistral => 'Círculo magistral',
        AeternumCircle.consagrado => 'Círculo consagrado',
        AeternumCircle.emergente => 'Círculo emergente',
        AeternumCircle.iniciado => 'Círculo iniciado',
      };

  String get shortLabel => switch (this) {
        AeternumCircle.legendario => 'Legendario',
        AeternumCircle.magistral => 'Magistral',
        AeternumCircle.consagrado => 'Consagrado',
        AeternumCircle.emergente => 'Emergente',
        AeternumCircle.iniciado => 'Iniciado',
      };
}

class ArtistRankingEntry {
  final UserProfile profile;
  final int position;
  final int score;
  final AeternumCircle circle;

  const ArtistRankingEntry({
    required this.profile,
    required this.position,
    required this.score,
    required this.circle,
  });

  /// Índice con rendimiento decreciente en las cifras sociales.
  ///
  /// Una comunidad enorme importa, pero no puede borrar una trayectoria con
  /// obra y colecciones. Las raíces cuadradas reducen ese efecto de volumen;
  /// las obras y colecciones tienen topes para que publicar por cantidad no
  /// se convierta en una estrategia de ranking.
  static int scoreFor(UserProfile profile) {
    final community = math.sqrt(math.max(0, profile.followersCount)) * 24;
    final recognition = math.sqrt(math.max(0, profile.totalLikesReceived)) * 18;
    final published = math.min(math.max(0, profile.worksCount), 100) * 15;
    final curated = math.min(math.max(0, profile.collectionsCount), 50) * 10;
    final verified = profile.isArtistVerified ? 120 : 0;

    return (community + recognition + published + curated + verified).round();
  }

  static AeternumCircle circleFor(int score) => switch (score) {
        >= 2500 => AeternumCircle.legendario,
        >= 1200 => AeternumCircle.magistral,
        >= 500 => AeternumCircle.consagrado,
        >= 150 => AeternumCircle.emergente,
        _ => AeternumCircle.iniciado,
      };

  /// Orden estable y reproducible. En empate gana primero el reconocimiento,
  /// luego la comunidad y por último el identificador público.
  static List<ArtistRankingEntry> rank(Iterable<UserProfile> profiles) {
    final scored = profiles
        .map((profile) => (profile: profile, score: scoreFor(profile)))
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byLikes = b.profile.totalLikesReceived
            .compareTo(a.profile.totalLikesReceived);
        if (byLikes != 0) return byLikes;
        final byFollowers =
            b.profile.followersCount.compareTo(a.profile.followersCount);
        if (byFollowers != 0) return byFollowers;
        return a.profile.username.compareTo(b.profile.username);
      });

    return List.unmodifiable([
      for (var index = 0; index < scored.length; index++)
        ArtistRankingEntry(
          profile: scored[index].profile,
          position: index + 1,
          score: scored[index].score,
          circle: circleFor(scored[index].score),
        ),
    ]);
  }
}
