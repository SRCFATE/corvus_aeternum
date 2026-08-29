import 'package:corvus_aeternum/shared/widgets/conspiracy_emblem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const houses = <({String code, String symbol, String rarity, Color color})>[
    (
      code: 'cuervo_negro',
      symbol: 'cuervo',
      rarity: 'root',
      color: Color(0xFF6F5A91)
    ),
    (
      code: 'velo_ceniza',
      symbol: 'mascara',
      rarity: 'free',
      color: Color(0xFFAAA097)
    ),
    (
      code: 'llama_perpetua',
      symbol: 'vela',
      rarity: 'free',
      color: Color(0xFFF65F1E)
    ),
    (
      code: 'umbral',
      symbol: 'puerta',
      rarity: 'free',
      color: Color(0xFF4AA2CF)
    ),
    (
      code: 'silencio_rojo',
      symbol: 'gota',
      rarity: 'free',
      color: Color(0xFF81183F)
    ),
    (
      code: 'espejo_partido',
      symbol: 'fragmento',
      rarity: 'free',
      color: Color(0xFF8574B4)
    ),
    (
      code: 'hueso_y_tinta',
      symbol: 'pluma',
      rarity: 'free',
      color: Color(0xFFD3BB9C)
    ),
    (
      code: 'luna_hendida',
      symbol: 'media_luna',
      rarity: 'free',
      color: Color(0xFF46579B)
    ),
    (
      code: 'raices_profundas',
      symbol: 'raiz',
      rarity: 'free',
      color: Color(0xFF27632D)
    ),
    (
      code: 'cristal_oscuro',
      symbol: 'cristal',
      rarity: 'free',
      color: Color(0xFF51868A)
    ),
    (
      code: 'viento_susurrante',
      symbol: 'espiral',
      rarity: 'free',
      color: Color(0xFF6E9D5C)
    ),
    (
      code: 'faro_sin_luz',
      symbol: 'torre',
      rarity: 'free',
      color: Color(0xFF939BA5)
    ),
    (
      code: 'sombra_plegada',
      symbol: 'pliegue',
      rarity: 'free',
      color: Color(0xFF724740)
    ),
    (
      code: 'eco_final',
      symbol: 'campana',
      rarity: 'free',
      color: Color(0xFF9A9AA7)
    ),
    (
      code: 'pacto_de_sangre',
      symbol: 'espada_cruzada',
      rarity: 'unlockable',
      color: Color(0xFFC11521)
    ),
    (
      code: 'reloj_detenido',
      symbol: 'reloj',
      rarity: 'unlockable',
      color: Color(0xFFC1B11F)
    ),
    (
      code: 'abismo_azul',
      symbol: 'profundidad',
      rarity: 'unlockable',
      color: Color(0xFF1046A2)
    ),
    (
      code: 'nombre_prohibido',
      symbol: 'sello',
      rarity: 'unlockable',
      color: Color(0xFF5C5C5C)
    ),
    (
      code: 'primer_cuervo',
      symbol: 'ojo_abierto',
      rarity: 'legendary',
      color: Color(0xFFCCE817)
    ),
    (
      code: 'dios_olvidado',
      symbol: 'vacio',
      rarity: 'legendary',
      color: Color(0xFF8B17CF)
    ),
    (
      code: 'imperial',
      symbol: 'corona',
      rarity: 'unlockable',
      color: Color(0xFFA35629)
    ),
    (
      code: 'eclipse',
      symbol: 'disco',
      rarity: 'legendary',
      color: Color(0xFF986CDA)
    ),
  ];

  testWidgets('renders the 22 conspiracy emblems on a compact mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Wrap(
              children: [
                for (final house in houses)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ConspiracyEmblem(
                      code: house.code,
                      symbol: house.symbol,
                      label: house.code,
                      rarity: house.rarity,
                      accent: house.color,
                      size: 48,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final house in houses) {
      expect(
        find.bySemanticsLabel('Emblema de ${house.code}'),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
