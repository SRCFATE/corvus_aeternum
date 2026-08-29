import 'package:corvus_aeternum/features/arena/arena_page.dart';
import 'package:corvus_aeternum/models/arena.dart';
import 'package:corvus_aeternum/services/arena_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arena renders challenges and creation form on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ArenaPage(
          service: _FakeArenaService(),
          profileIdOverride: 'profile-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Desafios y duelos de arte'), findsOneWidget);
    expect(find.text('La memoria del fuego'), findsOneWidget);
    expect(find.text('Duelo monocromo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Crear desafio'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva convocatoria'), findsOneWidget);
    expect(find.text('Consigna creativa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeArenaService extends ArenaService {
  @override
  Future<List<ArenaChallenge>> getChallenges() async => [
        _challenge('challenge-1', 'La memoria del fuego', 'challenge'),
        _challenge('challenge-2', 'Duelo monocromo', 'duel'),
      ];
}

ArenaChallenge _challenge(String id, String title, String format) {
  final now = DateTime.now();
  return ArenaChallenge(
    id: id,
    creatorProfileId: 'profile-1',
    title: title,
    brief: 'Interpreta una memoria sin recurrir a una escena literal.',
    format: format,
    discipline: 'Multidisciplinario',
    theme: 'Memoria',
    rules: const ['Una obra por artista'],
    prizeDescription: '',
    status: 'open',
    visibility: 'public',
    startsAt: now.subtract(const Duration(hours: 1)),
    endsAt: now.add(const Duration(days: 7)),
    votingEndsAt: now.add(const Duration(days: 9)),
    maxEntries: format == 'duel' ? 2 : 50,
    createdAt: now,
  );
}
