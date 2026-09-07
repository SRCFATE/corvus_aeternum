import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/atelier/billing/data/entitlement_cache.dart';
import '../features/atelier/billing/data/entitlement_repository.dart';
import '../features/atelier/billing/domain/billing_models.dart';
import '../features/atelier/billing/services/entitlement_service.dart';

/// El estado de los derechos en la aplicación.
///
/// Flujo: al entrar se lee la copia local —para que la interfaz no parpadee ni
/// muestre candados falsos durante medio segundo— y en paralelo se pregunta al
/// servidor. Después se refresca cuando arranca la app, cuando cambia la
/// suscripción, cuando termina un cobro y cuando el artista lo pide.
///
/// Si la red falla, se conserva lo último conocido: perder la conexión no
/// puede cerrarle el taller a nadie.
class EntitlementProvider extends ChangeNotifier {
  final EntitlementRepository _repository;
  final EntitlementCache _cache;

  EntitlementProvider({
    EntitlementRepository? repository,
    EntitlementCache? cache,
  })  : _repository = repository ?? EntitlementRepository(),
        _cache = cache ?? EntitlementCache();

  Entitlements _entitlements = Entitlements.fallback();
  Map<String, bool> _flags = const {};
  UsageSnapshot _usage = UsageSnapshot.empty;

  String? _userId;
  bool _loading = false;
  bool _hydrated = false;
  bool _stale = false;
  String? _error;

  Entitlements get entitlements => _entitlements;
  Map<String, bool> get flags => _flags;
  UsageSnapshot get usage => _usage;

  bool get loading => _loading;

  /// Si ya se sabe algo, aunque venga de la copia local. Antes de esto la
  /// interfaz debe evitar pintar candados: no sabe todavía.
  bool get hydrated => _hydrated;

  /// Lo que se muestra viene de caché y el servidor aún no ha confirmado.
  bool get stale => _stale;

  String? get error => _error;

  EntitlementService get service => EntitlementService(
        entitlements: _entitlements,
        flags: _flags,
        usage: _usage,
      );

  SubscriptionState get subscription => _entitlements.subscription;
  List<WorkspaceSummary> get workspaces => _entitlements.workspaces;

  bool has(String featureKey) => _entitlements.has(featureKey);
  int limit(String featureKey) => _entitlements.limit(featureKey);
  bool isFlagEnabled(String flagKey) => _flags[flagKey] == true;

  /// Entrada al ciclo: se llama cuando hay perfil cargado.
  Future<void> load(String userId) async {
    if (_userId == userId && _hydrated) return;
    _userId = userId;

    final cached = await _cache.read(userId);
    if (cached != null) {
      _entitlements = cached.entitlements;
      _flags = cached.flags;
      _hydrated = true;
      _stale = true;
      notifyListeners();
    }

    await refresh();
  }

  Future<void> refresh({bool withUsage = true}) async {
    final userId = _userId;
    if (userId == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchEntitlements(),
        _repository.fetchFeatureFlags(),
      ]);

      _entitlements = results[0] as Entitlements;
      _flags = results[1] as Map<String, bool>;
      _hydrated = true;
      _stale = false;

      unawaited(_cache.save(
        userId: userId,
        entitlements: _entitlements,
        flags: _flags,
      ));

      if (withUsage) {
        // El consumo es informativo: que falle no invalida los derechos.
        try {
          _usage = await _repository.fetchUsage();
        } catch (error) {
          debugPrint('ATELIER USAGE ERROR: $error');
        }
      }
    } catch (error) {
      // Se conserva lo último conocido a propósito. Una caída del servidor no
      // debe degradar a nadie a Free a mitad de una sesión de escritura.
      _error = error.toString();
      debugPrint('ENTITLEMENTS REFRESH ERROR: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Tras volver del cobro el proveedor puede tardar unos segundos en avisar
  /// por webhook, así que se reintenta un par de veces antes de rendirse.
  Future<void> refreshAfterCheckout({
    Duration delay = const Duration(seconds: 2),
    int attempts = 3,
  }) async {
    final before = subscription.planCode;

    for (var i = 0; i < attempts; i++) {
      await refresh(withUsage: false);
      if (subscription.planCode != before) return;
      if (i < attempts - 1) await Future<void>.delayed(delay);
    }
  }

  Future<void> refreshUsage({String? workspaceId}) async {
    try {
      _usage = await _repository.fetchUsage(workspaceId: workspaceId);
      notifyListeners();
    } catch (error) {
      debugPrint('ATELIER USAGE ERROR: $error');
    }
  }

  /// Deja constancia de un momento del embudo. Nunca lleva contenido creativo
  /// y falla en silencio: la analítica no puede estorbar a quien escribe.
  Future<void> track(
    String event, {
    Map<String, String> properties = const {},
  }) async {
    try {
      await _repository.recordEvent(event, properties: properties);
    } catch (error) {
      debugPrint('BILLING EVENT ERROR: $error');
    }
  }

  Future<void> clear() async {
    _userId = null;
    _entitlements = Entitlements.fallback();
    _flags = const {};
    _usage = UsageSnapshot.empty;
    _hydrated = false;
    _stale = false;
    _error = null;
    await _cache.clear();
    notifyListeners();
  }
}
