import 'package:corvus_aeternum/features/conspiracies/conspiracy_strip.dart';
import 'package:corvus_aeternum/models/conspiracy_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = ConspiracySummary(
    id: 'root',
    code: 'cuervo_negro',
    name: 'Conspiración del Cuervo Negro',
    rarity: 'root',
    symbol: 'cuervo',
    accentHex: '#2B1B40',
    glowHex: '#2B1B40',
  );
  const primary = ConspiracySummary(
    id: 'primary',
    code: 'llama_perpetua',
    name: 'Conspiración de la Llama Perpetua',
    rarity: 'free',
    symbol: 'vela',
    accentHex: '#F65F1E',
    glowHex: '#F65F1E',
  );
  const legendary = ConspiracySummary(
    id: 'legendary',
    code: 'eclipse',
    name: 'Conspiración del Eclipse',
    rarity: 'legendary',
    symbol: 'disco',
    accentHex: '#986CDA',
    glowHex: '#986CDA',
  );

  testWidgets('profile emblems remain readable on mobile', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var registryOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileConspiracyEmblems(
              memberships: const EffectiveMemberships(
                root: root,
                primary: ConspiracyMembership(
                  house: primary,
                  role: 'primary',
                ),
                unlocks: [legendary],
              ),
              isOwnProfile: true,
              onOpenRegistry: () => registryOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EMBLEMAS DE CONSPIRACIÓN'), findsOneWidget);
    expect(find.text('Cuervo Negro'), findsOneWidget);
    expect(find.text('Llama Perpetua'), findsOneWidget);
    expect(find.text('Eclipse'), findsOneWidget);
    expect(find.text('Casa primaria'), findsOneWidget);
    expect(find.text('Legendaria'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Abrir Registro'));
    expect(registryOpened, isTrue);
  });
}
