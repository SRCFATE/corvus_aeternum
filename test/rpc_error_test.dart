import 'package:flutter_test/flutter_test.dart';
import 'package:corvus_aeternum/core/rpc_error.dart';

void main() {
  group('unwrapRpc', () {
    test('devuelve el mapa cuando la RPC responde ok', () {
      final result = unwrapRpc({'ok': true, 'profile': {'id': 'abc'}});
      expect(result['profile'], isA<Map>());
    });

    test('lanza CorvusRpcException con el reason_code del servidor', () {
      expect(
        () => unwrapRpc({'ok': false, 'reason_code': 'USERNAME_COOLDOWN'}),
        throwsA(isA<CorvusRpcException>()
            .having((e) => e.reasonCode, 'reasonCode', 'USERNAME_COOLDOWN')),
      );
    });

    test('un ok ausente se trata como fallo, no como éxito', () {
      expect(() => unwrapRpc(<String, dynamic>{}),
          throwsA(isA<CorvusRpcException>()));
    });

    test('conserva los datos extra del servidor para la UI', () {
      try {
        unwrapRpc({
          'ok': false,
          'reason_code': 'USERNAME_COOLDOWN',
          'next_change_at': '2027-06-10T00:00:00Z',
        });
        fail('debió lanzar');
      } on CorvusRpcException catch (e) {
        expect(e.data['next_change_at'], '2027-06-10T00:00:00Z');
      }
    });
  });

  group('corvusReasonMessage', () {
    test('traduce los códigos de identidad a la voz del archivo', () {
      expect(corvusReasonMessage('USERNAME_TAKEN'), contains('registrado'));
      expect(corvusReasonMessage('USERNAME_COOLDOWN'), contains('año'));
      expect(corvusReasonMessage('PROFILE_ALREADY_SET'), contains('sellado'));
    });

    test('traduce los códigos de moderación', () {
      expect(corvusReasonMessage('NOT_AUTHORIZED'), contains('curatorial'));
      expect(corvusReasonMessage('CANNOT_BAN_SELF'), contains('propia'));
      expect(corvusReasonMessage('CANNOT_BAN_ADMIN'), contains('administrador'));
    });

    test('nunca filtra el código crudo ante un valor desconocido', () {
      final msg = corvusReasonMessage('ALGO_INESPERADO_42');
      expect(msg, isNot(contains('ALGO_INESPERADO_42')));
      expect(msg, isNotEmpty);
    });

    test('un código nulo devuelve mensaje utilizable', () {
      expect(corvusReasonMessage(null), isNotEmpty);
    });
  });
}
