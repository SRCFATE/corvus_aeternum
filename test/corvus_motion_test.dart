import 'package:corvus_aeternum/shared/widgets/corvus_button.dart';
import 'package:corvus_aeternum/shared/widgets/corvus_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La capa de movimiento tiene una obligación por encima de las demás: no
/// puede esconder contenido ni cambiar dónde están las cosas. Es puramente
/// decorativa, y estas pruebas fijan justo eso, porque en su primera versión
/// falló en las dos.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  group('CorvusReveal', () {
    testWidgets('desplaza en píxeles, no en fracciones del hijo',
        (tester) async {
      // El fallo original: se usó `AnimatedSlide`, que mide en fracciones del
      // tamaño del propio widget. Un `beginOffset` de 14 se convertía en el
      // 14 % de la altura del hijo, o sea 280 px en un bloque de 2000. Bastaba
      // para empujar fuera de pantalla lo que envolvía.
      await pump(
        tester,
        const SingleChildScrollView(
          child: CorvusReveal(
            beginOffset: Offset(0, 14),
            child: SizedBox(height: 2000, child: Text('bloque largo')),
          ),
        ),
      );

      // Primer fotograma: aún oculto y desplazado.
      final inicio = tester.getTopLeft(find.text('bloque largo')).dy;

      await tester.pumpAndSettle();
      final fin = tester.getTopLeft(find.text('bloque largo')).dy;

      // Catorce píxeles de recorrido, con margen para el redondeo. Si volviera
      // a interpretarse como fracción, esta diferencia rondaría los 280.
      expect((inicio - fin).abs(), lessThan(20));
    });

    testWidgets('termina siempre visible', (tester) async {
      await pump(
        tester,
        const CorvusReveal(child: Text('contenido')),
      );
      await tester.pumpAndSettle();

      final opacidad = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('contenido'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacidad.opacity, 1);
    });
  });

  group('CorvusScrollReveal', () {
    testWidgets('muestra lo que está en el encuadre', (tester) async {
      // El otro fallo original: la búsqueda del encuadre partía del
      // `RenderObject` del `Scrollable` suponiendo que era un `RenderBox`. No
      // siempre lo es, la comprobación se caía en silencio y el hijo se
      // quedaba en opacidad cero para siempre. Un fallo de animación que
      // esconde contenido es un fallo de contenido.
      await pump(
        tester,
        CustomScrollView(
          slivers: const [
            SliverToBoxAdapter(
              child: CorvusScrollReveal(child: Text('a la vista')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final opacidad = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('a la vista'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacidad.opacity, 1, reason: 'el contenido se quedó invisible');
    });

    testWidgets('se enciende igualmente fuera de un scroll', (tester) async {
      await pump(tester, const CorvusScrollReveal(child: Text('suelto')));
      await tester.pumpAndSettle();

      final opacidad = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('suelto'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacidad.opacity, 1);
    });
  });

  group('CorvusButton', () {
    testWidgets('un toque es una acción, no dos', (tester) async {
      // El hundido al pulsar se añadió envolviendo el botón. Hecho con un
      // `GestureDetector`, el `onTap` se dispararía dos veces —el del
      // envoltorio y el del botón de Material—, y en un formulario eso es un
      // envío duplicado: una obra publicada dos veces, un cobro repetido.
      var pulsaciones = 0;

      await pump(
        tester,
        CorvusButton(
          label: 'Publicar',
          onPressed: () => pulsaciones++,
        ),
      );

      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      expect(pulsaciones, 1);
    });

    testWidgets('mientras carga no acepta toques', (tester) async {
      var pulsaciones = 0;

      await pump(
        tester,
        CorvusButton(
          label: 'Publicar',
          isLoading: true,
          onPressed: () => pulsaciones++,
        ),
      );

      await tester.tap(find.byType(CorvusButton), warnIfMissed: false);
      // `pumpAndSettle` no: el aro de espera gira sin fin y nunca se asienta.
      await tester.pump(const Duration(milliseconds: 400));

      expect(pulsaciones, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('CorvusPressable', () {
    testWidgets('sin acción no se traga el toque de lo que envuelve',
        (tester) async {
      // Este ya costó una vez: un `GestureDetector` opaco con `onTap` nulo
      // dejó de abrir el menú "Más". Envolvemos tarjetas que llevan sus
      // propios botones dentro, así que el envoltorio inerte tiene que ser
      // transparente al puntero.
      var interior = 0;

      await pump(
        tester,
        CorvusPressable(
          child: Center(
            child: TextButton(
              onPressed: () => interior++,
              child: const Text('dentro'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('dentro'));
      await tester.pumpAndSettle();

      expect(interior, 1);
    });
  });
}
