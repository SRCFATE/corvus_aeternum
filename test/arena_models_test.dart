import 'package:corvus_aeternum/models/arena.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('challenge derives voting and closed states from its schedule', () {
    final now = DateTime.now();
    final voting = _challenge(
      startsAt: now.subtract(const Duration(days: 3)),
      endsAt: now.subtract(const Duration(hours: 1)),
      votingEndsAt: now.add(const Duration(days: 1)),
    );
    final closed = _challenge(
      startsAt: now.subtract(const Duration(days: 4)),
      endsAt: now.subtract(const Duration(days: 2)),
      votingEndsAt: now.subtract(const Duration(hours: 1)),
    );

    expect(voting.effectiveStatus, 'voting');
    expect(voting.acceptsEntries, isFalse);
    expect(voting.acceptsVotes, isTrue);
    expect(closed.effectiveStatus, 'closed');
    expect(closed.acceptsVotes, isFalse);
  });

  test('entry counts votes and identifies the viewer vote', () {
    final entry = ArenaEntry.fromMap({
      'id': 'entry-1',
      'challenge_id': 'challenge-1',
      'profile_id': 'artist-1',
      'title': 'Umbral',
      'statement': '',
      'status': 'submitted',
      'created_at': DateTime(2026).toIso8601String(),
      'arena_votes': [
        {'voter_profile_id': 'viewer-1'},
        {'voter_profile_id': 'viewer-2'},
      ],
    }, viewerId: 'viewer-1');

    expect(entry.votesCount, 2);
    expect(entry.votedByMe, isTrue);
  });
}

ArenaChallenge _challenge({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime votingEndsAt,
}) {
  return ArenaChallenge(
    id: 'challenge-1',
    creatorProfileId: 'profile-1',
    title: 'Desafio',
    brief: 'Consigna',
    format: 'challenge',
    discipline: 'Pintura',
    theme: 'Memoria',
    rules: const [],
    prizeDescription: '',
    status: 'open',
    visibility: 'public',
    startsAt: startsAt,
    endsAt: endsAt,
    votingEndsAt: votingEndsAt,
    maxEntries: 20,
    createdAt: startsAt,
  );
}
