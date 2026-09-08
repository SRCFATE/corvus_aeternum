import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/atelier_provider.dart';
import 'providers/app_preferences_provider.dart';
import 'providers/conspiration_provider.dart';
import 'providers/entitlement_provider.dart';
import 'services/conspiracy_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URLs reales en web: /work/:id en vez de /#/work/:id, para que un enlace
  // compartido se lea como una dirección y no como un fragmento. Exige que el
  // hosting sirva index.html en cualquier ruta (web/_redirects). En Android,
  // iOS y escritorio esta llamada no hace nada.
  usePathUrlStrategy();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F0F1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const CorvusApp());
}

class CorvusApp extends StatefulWidget {
  const CorvusApp({super.key});

  @override
  State<CorvusApp> createState() => _CorvusAppState();
}

class _CorvusAppState extends State<CorvusApp> {
  late final GoRouterWrapper _routerWrapper;

  @override
  void initState() {
    super.initState();
    _routerWrapper = GoRouterWrapper();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ConspirationProvider()),
        ChangeNotifierProvider(create: (_) => AtelierProvider()),
        ChangeNotifierProvider(create: (_) => EntitlementProvider()),
        ChangeNotifierProvider(
          create: (_) => AppPreferencesProvider()..initialize(),
        ),
      ],
      child: _ConspirationLoader(
        router: _routerWrapper.router,
      ),
    );
  }
}

/// Escucha cambios en AuthProvider y carga la conspiración del usuario.
class _ConspirationLoader extends StatefulWidget {
  final dynamic router;
  const _ConspirationLoader({required this.router});

  @override
  State<_ConspirationLoader> createState() => _ConspirationLoaderState();
}

class _ConspirationLoaderState extends State<_ConspirationLoader>
    with WidgetsBindingObserver {
  final _conspiracyService = ConspiracyService();
  String? _lastConspirationId;
  String? _presenceProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _recordPresence() async {
    final profileId = context.read<AuthProvider>().profile?.id;
    if (profileId == null) return;
    try {
      await _conspiracyService.recordPresence();
    } catch (error) {
      debugPrint('CONSPIRACY PRESENCE ERROR: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _recordPresence();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final cp = context.read<ConspirationProvider>();
    final cid = auth.profile?.conspiracyId;
    final profileId = auth.profile?.id;
    if (cid != _lastConspirationId) {
      _lastConspirationId = cid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cp.loadForUser(cid);
      });
    }
    if (profileId != _presenceProfileId) {
      _presenceProfileId = profileId;
      final entitlements = context.read<EntitlementProvider>();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (profileId == null) {
          // Al cerrar sesión la copia local se borra: los derechos de una
          // cuenta no pueden sobrevivir a su sesión en el dispositivo.
          entitlements.clear();
          return;
        }
        _recordPresence();
        entitlements.load(profileId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ConspirationProvider>();
    final preferences = context.watch<AppPreferencesProvider>();

    return MaterialApp.router(
      title: 'Corvus Aeternum',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildDark(
        accent: cp.accent,
        base: cp.base,
        surface: cp.surface,
        highContrast: preferences.highContrast,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(16) / 16;
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                media.disableAnimations || preferences.reduceMotion,
            textScaler: TextScaler.linear(
              systemScale * (preferences.largerText ? 1.15 : 1),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: widget.router,
    );
  }
}

class GoRouterWrapper {
  late final router = buildRouter();
}
