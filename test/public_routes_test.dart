import 'package:corvus_aeternum/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// Corvus es abierto para descubrir y consultar, y autenticado para
/// participar. Estas pruebas fijan esa frontera y el rescate del enlace que
/// seguía el visitante, para que abrir la web no se lleve por delante ni la
/// privacidad ni los enlaces compartidos.
void main() {
  String? forVisitor(String location) => resolveAuthRedirect(
        isAuth: false,
        hasProfile: false,
        location: location,
        uri: Uri.parse(location),
      );

  group('un visitante sin sesión puede descubrir y consultar', () {
    const publicas = [
      '/discover',
      '/artists',
      '/arena',
      '/ranking',
      '/challenges',
      '/work/abc-123',
      '/work/abc-123/chapter/2',
      '/profile/carlos',
      '/artist/8f2c',
      '/certificate/CA-0001',
    ];

    for (final ruta in publicas) {
      test('$ruta se abre sin sesión', () {
        expect(forVisitor(ruta), isNull);
      });
    }
  });

  group('participar y crear siguen pidiendo sesión', () {
    const privadas = [
      '/feed',
      '/atelier',
      '/mundiarium',
      '/archive',
      '/upload',
      '/notifications',
      '/collections',
      '/collection/abc',
      '/auctions',
      '/certificates',
      '/insights',
      '/planner',
      '/forums',
      '/glossary',
      '/conspiracies',
      '/admin',
      '/profile',
      '/profile/edit',
    ];

    for (final ruta in privadas) {
      test('$ruta manda al login', () {
        expect(forVisitor(ruta), startsWith('/login?redirect='));
      });
    }

    test('el perfil propio y su edición no se cuelan por /profile/:username',
        () {
      expect(isPublicLocation('/profile'), isFalse);
      expect(isPublicLocation('/profile/edit'), isFalse);
      expect(isPublicLocation('/profile/carlos'), isTrue);
    });
  });

  group('el enlace que seguía el visitante no se pierde', () {
    test('la obra concreta viaja en el login', () {
      expect(
        forVisitor('/upload'),
        '/login?redirect=${Uri.encodeComponent('/upload')}',
      );
    });

    test('se conserva la query original', () {
      final destino = Uri.parse('/collection/abc?tab=obras');

      expect(
        resolveAuthRedirect(
          isAuth: false,
          hasProfile: false,
          location: '/collection/abc',
          uri: destino,
        ),
        '/login?redirect=${Uri.encodeComponent('/collection/abc?tab=obras')}',
      );
    });

    test('tras entrar vuelve al destino guardado', () {
      expect(
        resolveAuthRedirect(
          isAuth: true,
          hasProfile: true,
          location: '/login',
          uri: Uri.parse('/login?redirect=%2Fwork%2F123'),
        ),
        '/work/123',
      );
    });

    test('sin destino guardado, entrar lleva a Descubrir', () {
      expect(
        resolveAuthRedirect(
          isAuth: true,
          hasProfile: true,
          location: '/login',
          uri: Uri.parse('/login'),
        ),
        '/discover',
      );
    });

    test('un destino externo se descarta', () {
      expect(redirectTargetOf(Uri.parse('/login?redirect=https://otro.com')),
          isNull);
      expect(redirectTargetOf(Uri.parse('/login?redirect=//otro.com')), isNull);
      expect(redirectTargetOf(Uri.parse('/login?redirect=/work/123')),
          '/work/123');
    });
  });

  group('perfil sin terminar', () {
    test('una sesión sin perfil pasa por /create-profile', () {
      expect(
        resolveAuthRedirect(
          isAuth: true,
          hasProfile: false,
          location: '/discover',
          uri: Uri.parse('/discover'),
        ),
        '/create-profile',
      );
    });

    test('con el perfil ya creado, /create-profile devuelve al destino', () {
      expect(
        resolveAuthRedirect(
          isAuth: true,
          hasProfile: true,
          location: '/create-profile',
          uri: Uri.parse('/create-profile?redirect=%2Fwork%2F123'),
        ),
        '/work/123',
      );
    });

    test('la recuperación de contraseña sigue abierta sin sesión', () {
      expect(forVisitor('/recover'), isNull);
      expect(forVisitor('/login'), isNull);
      expect(forVisitor('/register'), isNull);
    });
  });
}
