import 'package:corvus_aeternum/features/auth/recover_password_page.dart';
import 'package:corvus_aeternum/core/rpc_error.dart';
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
      expect(find.text('Escribe el código que recibiste'), findsOneWidget);
      expect(find.text('Usa al menos 6 caracteres'), findsOneWidget);

      final fields = find.byType(TextFormField);

      // Un código de otra longitud se rechaza antes de salir a la red.
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'unaClaveLarga');
      await tester.enterText(fields.at(2), 'unaClaveLarga');
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('El código tiene 8 caracteres'), findsOneWidget);

      // Con código válido pero contraseñas distintas.
      await tester.enterText(fields.at(0), 'ABCD2345');
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

  group('normalización del código escrito', () {
    // El código viaja en un correo: la gente lo pega con espacios, en
    // minúsculas o con guiones. Todo eso debe seguir funcionando.
    test('pasa a mayúsculas', () {
      expect(AuthService.normalizeRecoveryCode('abcd2345'), 'ABCD2345');
    });

    test('quita espacios y guiones al pegar', () {
      expect(AuthService.normalizeRecoveryCode(' ABCD-2345 '), 'ABCD2345');
      expect(AuthService.normalizeRecoveryCode('ABC D23 45'), 'ABCD2345');
    });

    test('descarta cualquier símbolo ajeno al alfabeto', () {
      expect(AuthService.normalizeRecoveryCode('«ABCD2345»'), 'ABCD2345');
    });

    test('texto vacío no revienta', () {
      expect(AuthService.normalizeRecoveryCode(''), '');
      expect(AuthService.normalizeRecoveryCode('   '), '');
    });
  });

  group('errores del envío llegan legibles', () {
    // invoke() lanza FunctionException en 4xx/5xx en vez de devolver el
    // cuerpo: si no se rescata el reason_code de `details`, el artista ve la
    // excepción cruda de Dart en pantalla.
    test('cada código de envío tiene mensaje propio', () {
      for (final code in [
        'EMAIL_NOT_CONFIGURED',
        'EMAIL_SEND_FAILED',
        'EMAIL_DOMAIN_NOT_VERIFIED',
        'EMAIL_INVALID',
        'RECOVERY_RATE_LIMIT',
        'RECOVERY_ISSUE_FAILED',
      ]) {
        final msg = corvusReasonMessage(code);
        expect(msg, isNotEmpty);
        expect(msg, isNot(contains(code)),
            reason: '$code se está mostrando crudo');
        expect(msg, isNot(contains('Exception')));
      }
    });

    test('un reason_code desconocido tampoco filtra jerga', () {
      final msg = corvusReasonMessage('ALGO_RARO_123');
      expect(msg, isNot(contains('ALGO_RARO_123')));
      expect(msg, isNot(contains('FunctionException')));
    });

    test('la excepción se construye con los datos del servidor', () {
      const e = CorvusRpcException(
        'EMAIL_NOT_CONFIGURED',
        {'ok': false, 'reason_code': 'EMAIL_NOT_CONFIGURED'},
      );
      expect(e.reasonCode, 'EMAIL_NOT_CONFIGURED');
      expect(e.message, contains('configurado'));
      expect(e.toString(), isNot(contains('Instance of')));
    });
  });
}
