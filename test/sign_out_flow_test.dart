import 'package:corvus_aeternum/features/auth/sign_out_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cerrar sesión es una acción que interrumpe el trabajo: nunca debe ocurrir
/// por un toque accidental.
void main() {
  Future<bool?> pumpAndAsk(WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showSignOutConfirmation(context);
                },
                child: const Text('salir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('salir'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('la advertencia aparece antes de cerrar sesión', (tester) async {
    await pumpAndAsk(tester);

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(find.textContaining('quedan intactos'), findsOneWidget);
    expect(find.text('Permanecer'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('confirmar devuelve true; cancelar devuelve false',
      (tester) async {
    bool? captured;

    Future<void> pumpWith(String buttonToTap) async {
      captured = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    captured = await showSignOutConfirmation(context);
                  },
                  child: const Text('salir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('salir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(buttonToTap));
      await tester.pumpAndSettle();
    }

    await pumpWith('Cerrar sesión');
    expect(captured, isTrue, reason: 'confirmar debe devolver true');

    await pumpWith('Permanecer');
    expect(captured, isFalse, reason: 'cancelar no debe cerrar la sesión');
  });

  testWidgets('tocar fuera del diálogo no cierra la sesión', (tester) async {
    bool? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await showSignOutConfirmation(context);
                },
                child: const Text('salir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('salir'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10)); // fuera del diálogo
    await tester.pumpAndSettle();

    expect(find.byType(SignOutDialog), findsNothing);
    expect(captured, isNot(isTrue),
        reason: 'descartar tocando fuera no es una confirmación');
  });
}
