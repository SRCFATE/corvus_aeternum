import 'package:corvus_aeternum/features/conspiracies/conspiracies_registry_page.dart';
import 'package:corvus_aeternum/features/glossary/glossary_page.dart';
import 'package:corvus_aeternum/models/conspiration.dart';
import 'package:corvus_aeternum/models/conspiracy_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('glossary keeps search, reading and saved terms usable on mobile',
      (tester) async {
    await _pumpAtSize(tester, const Size(390, 844), const GlossaryPage());

    expect(find.text('Glosario'), findsOneWidget);
    expect(find.byTooltip('Ver terminos guardados'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Fantasia'),
      420,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Guardar termino').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Quitar de guardados'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conspiracy book filters its folios without mobile overflow',
      (tester) async {
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      ConspiraciesRegistryPage(initialCatalog: _houses()),
    );

    expect(find.text('Registro de las Casas'), findsOneWidget);
    expect(find.text('INDICE DEL LIBRO'), findsOneWidget);
    expect(find.text('Cuervo Negro'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Corona');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Corona del Eclipse'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Corona del Eclipse'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conspiracy folio renders server progress and active effect',
      (tester) async {
    await _pumpAtSize(
      tester,
      const Size(900, 900),
      ConspiraciesRegistryPage(
        initialCatalog: _houses(),
        initialProgress: const [
          ConspiracyProgress(
            conspiracyId: 'root',
            code: 'cuervo_negro',
            name: 'Conspiracion del Cuervo Negro',
            metricValue: 1,
            targetValue: 1,
            level: 1,
            state: 'awakened',
            details: {
              'metric_label': 'Obras publicadas',
              'effect_key': 'root_awakened',
              'effect_active': true,
            },
          ),
        ],
      ),
    );

    expect(find.text('Obras publicadas'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Raíz despierta'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
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
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

List<Conspiration> _houses() => const [
      Conspiration(
        id: 'root',
        code: 'cuervo_negro',
        name: 'Conspiración del Cuervo Negro',
        accentHex: '#7F77DD',
        glowHex: '#7F77DD',
        glowIntensity: 0.2,
        motionProfile: 'default',
        uiRounding: 8,
        isActive: true,
        symbol: 'cuervo',
        lore: 'La casa raiz recibe a toda persona creadora.',
        mechanicGeneral: 'Casa de entrada al archivo.',
        mechanicPassive: 'Su emblema acompana el perfil.',
        mechanicActive: 'Despierta con la primera obra.',
        isDefault: true,
        rarity: 'root',
        registryNumber: '1',
      ),
      Conspiration(
        id: 'free',
        code: 'velo_ceniza',
        name: 'Conspiración del Velo Ceniza',
        accentHex: '#9CA3AF',
        glowHex: '#9CA3AF',
        glowIntensity: 0.2,
        motionProfile: 'default',
        uiRounding: 8,
        isActive: true,
        symbol: 'mascara',
        lore: 'Una casa libre dedicada a identidades y nombres.',
        isDefault: false,
        rarity: 'free',
        registryNumber: '2',
      ),
      Conspiration(
        id: 'legendary',
        code: 'corona_eclipse',
        name: 'Conspiración de la Corona del Eclipse',
        accentHex: '#D6B15E',
        glowHex: '#D6B15E',
        glowIntensity: 0.25,
        motionProfile: 'default',
        uiRounding: 8,
        isActive: true,
        symbol: 'corona',
        lore: 'Una casa legendaria otorgada por el archivo.',
        mechanicGeneral: 'Reconocimiento excepcional.',
        isDefault: false,
        rarity: 'legendary',
        registryNumber: '22',
      ),
    ];
