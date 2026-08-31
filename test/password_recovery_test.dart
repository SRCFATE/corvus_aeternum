import 'package:corvus_aeternum/features/auth/recover_password_page.dart';
import 'package:corvus_aeternum/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La recuperación no usa enlace mágico porque en escritorio el correo abre el
/// navegador y nunca regresa a la app. Estas pruebas cubren la pantalla y el
/// caso que más se rompe: distinguir un código de un enlace pegado.
void main() {
  Future<void> pumpPage(WidgetTester tester, {String? email}) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: RecoverPasswordPage(initialEmail: email)),
    );
    await tester.pumpAndSettle();
  }

  group('pantalla', () {
    testWidgets('abre en el paso de solicitud', (tester) async {
      await pumpPage(tester);

      expect(find.text('PASO 1 DE 2'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
      expect(find.text('Enviar código'), findsOneWidget);
    });

    testWidgets('arrastra el correo escrito en el login', (tester) async {
      await pumpPage(tester, email: 'artista@corvus.mx');

      expect(find.text('artista@corvus.mx'), findsOneWidget);
    });

    testWidgets('rechaza un correo mal formado', (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextFormField).first, 'no-es-correo');
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();

      expect(find.text('Ese correo no parece válido'), findsOneWidget);
    });

    testWidgets('"Ya tengo un código" salta al paso 2 sin pedir el correo',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Ya tengo un código'));
      await tester.pumpAndSettle();

      expect(find.text('PASO 2 DE 2'), findsOneWidget);
      expect(find.text('Cambiar contraseña'), findsOneWidget);
    });

    testWidgets('el paso 2 exige código, longitud y coincidencia',
        (tester) async {
      await pumpPage(tester, email: 'artista@corvus.mx');
      await tester.tap(find.text('Ya tengo un código'));
      await tester.pumpAndSettle();

      // Sin nada: pide el código y la contraseña.
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Pega el código que recibiste'), findsOneWidget);
      expect(find.text('Usa al menos 6 caracteres'), findsOneWidget);

      // Contraseñas distintas.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'unaClaveLarga');
      await tester.enterText(fields.at(2), 'otraDistinta');
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('se puede volver al paso 1 para corregir el correo',
        (tester) async {
      await pumpPage(tester, email: 'artista@corvus.mx');
      await tester.tap(find.text('Ya tengo un código'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(find.text('PASO 1 DE 2'), findsOneWidget);
    });
  });

  group('lectura del código pegado', () {
    // Según cómo esté la plantilla del correo, el artista pegará un código de
    // seis dígitos o el enlace completo. Ambos deben funcionar.
    test('un código de seis dígitos no se confunde con un enlace', () {
      expect(AuthService.extractTokenHash('123456'), isNull);
      expect(AuthService.extractTokenHash('  907214 '), isNull);
    });

    test('extrae token_hash de la query del enlace', () {
      const link =
          'https://qqmzeapepoxadspupmuz.supabase.co/auth/v1/verify'
          '?token_hash=pkce_abc123&type=recovery';
      expect(AuthService.extractTokenHash(link), 'pkce_abc123');
    });

    test('extrae el token cuando viene tras el fragmento', () {
      const link = 'https://corvus.app/reset#token=frag987&type=recovery';
      expect(AuthService.extractTokenHash(link), 'frag987');
    });

    test('prefiere token_hash sobre token si vienen ambos', () {
      const link = 'https://corvus.app/r?token=viejo&token_hash=nuevo';
      expect(AuthService.extractTokenHash(link), 'nuevo');
    });

    test('devuelve null si el enlace no trae token', () {
      expect(
        AuthService.extractTokenHash('https://corvus.app/reset?type=recovery'),
        isNull,
      );
    });

    test('texto arbitrario no revienta el analizador', () {
      expect(AuthService.extractTokenHash(''), isNull);
      expect(AuthService.extractTokenHash('hola mundo'), isNull);
    });
  });
}
