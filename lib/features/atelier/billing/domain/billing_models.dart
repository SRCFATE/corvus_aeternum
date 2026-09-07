import 'dart:convert';

/// Modelos del módulo comercial de Atelier.
///
/// Todos se construyen desde el mapa que devuelve Supabase y ninguno lleva
/// lógica de negocio: la decisión de si algo está permitido la toma el
/// servidor y aquí solo se lee. Lo que sí vive aquí es la aritmética de
/// presentación —precio por mes de un plan anual, porcentaje de cuota usado—,
/// porque es formato, no permiso.

/// Un límite de -1 significa ilimitado. Se escribe así en toda la pila.
const int kUnlimited = -1;

class AtelierPlan {
  final String code;
  final String name;
  final String tagline;
  final String description;
  final String scope;
  final int tierRank;
  final String badge;
  final bool isRecommended;
  final int sortOrder;
  final List<String> highlights;
  final List<PlanPrice> prices;

  const AtelierPlan({
    required this.code,
    required this.name,
    required this.tagline,
    required this.description,
    required this.scope,
    required this.tierRank,
    required this.badge,
    required this.isRecommended,
    required this.sortOrder,
    required this.highlights,
    required this.prices,
  });

  bool get isFree => prices.isEmpty || prices.every((p) => p.unitAmount == 0);
  bool get isWorkspaceScoped => scope == 'workspace';

  PlanPrice? priceFor(String interval) {
    for (final price in prices) {
      if (price.interval == interval) return price;
    }
    return null;
  }

  PlanPrice? get monthlyPrice => priceFor('month');
  PlanPrice? get yearlyPrice => priceFor('year');

  /// Cuánto se ahorra al año pagando anual, en porcentaje entero. Null si no
  /// hay las dos modalidades: inventar un ahorro sería un patrón oscuro.
  int? get yearlySavingPercent {
    final monthly = monthlyPrice;
    final yearly = yearlyPrice;
    if (monthly == null || yearly == null || monthly.unitAmount <= 0) {
      return null;
    }
    final twelveMonths = monthly.unitAmount * 12;
    if (yearly.unitAmount >= twelveMonths) return null;
    return (((twelveMonths - yearly.unitAmount) / twelveMonths) * 100).round();
  }

  factory AtelierPlan.fromMap(
    Map<String, dynamic> map, {
    List<PlanPrice> prices = const [],
  }) {
    return AtelierPlan(
      code: map['code'] as String,
      name: map['name'] as String? ?? '',
      tagline: map['tagline'] as String? ?? '',
      description: map['description'] as String? ?? '',
      scope: map['scope'] as String? ?? 'user',
      tierRank: (map['tier_rank'] as num?)?.toInt() ?? 0,
      badge: map['badge'] as String? ?? '',
      isRecommended: map['is_recommended'] as bool? ?? false,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      highlights: _stringList(map['highlights']),
      prices: prices,
    );
  }
}

class PlanPrice {
  final String id;
  final String productId;
  final String provider;
  final String currency;
  final int unitAmount;
  final String interval;
  final int trialDays;
  final bool isDefault;
  final String label;

  const PlanPrice({
    required this.id,
    required this.productId,
    required this.provider,
    required this.currency,
    required this.unitAmount,
    required this.interval,
    required this.trialDays,
    required this.isDefault,
    required this.label,
  });

  /// El importe llega en centavos. Un precio en coma flotante en la base sería
  /// un redondeo esperando a ocurrir.
  double get amount => unitAmount / 100;

  /// Lo que cuesta cada mes de un plan anual, para poder compararlos de frente.
  double get monthlyEquivalent =>
      interval == 'year' ? amount / 12 : amount;

  factory PlanPrice.fromMap(Map<String, dynamic> map) {
    final metadata = _jsonMap(map['metadata']);
    return PlanPrice(
      id: map['id'] as String,
      productId: map['product_id'] as String? ?? '',
      provider: map['provider'] as String? ?? 'stripe',
      currency: map['currency'] as String? ?? 'MXN',
      unitAmount: (map['unit_amount'] as num?)?.toInt() ?? 0,
      interval: map['billing_interval'] as String? ?? 'month',
      trialDays: (map['trial_days'] as num?)?.toInt() ?? 0,
      isDefault: map['is_default'] as bool? ?? false,
      label: metadata['label'] as String? ?? '',
    );
  }
}

/// El estado de la suscripción tal y como lo publica el servidor.
class SubscriptionState {
  final String planCode;
  final String status;
  final String? subscriptionId;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  const SubscriptionState({
    required this.planCode,
    required this.status,
    this.subscriptionId,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  static const free = SubscriptionState(planCode: 'free', status: 'free');

  bool get isFree => planCode == 'free';
  bool get isActive => status == 'active' || status == 'trialing';
  bool get isTrialing => status == 'trialing';

  /// Un cobro rechazado no cierra el taller: da acceso y pide arreglarlo.
  bool get needsAttention => status == 'past_due' || status == 'incomplete';

  bool get willEnd => cancelAtPeriodEnd && currentPeriodEnd != null;

  factory SubscriptionState.fromMap(Map<String, dynamic> map) {
    return SubscriptionState(
      planCode: map['code'] as String? ?? 'free',
      status: map['status'] as String? ?? 'free',
      subscriptionId: map['subscription_id'] as String?,
      currentPeriodEnd: _date(map['current_period_end']),
      cancelAtPeriodEnd: map['cancel_at_period_end'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'code': planCode,
        'status': status,
        'subscription_id': subscriptionId,
        'current_period_end': currentPeriodEnd?.toIso8601String(),
        'cancel_at_period_end': cancelAtPeriodEnd,
      };
}

/// El conjunto resuelto de derechos. Es lo único que la app consulta para
/// saber qué puede ofrecer.
class Entitlements {
  final SubscriptionState subscription;
  final Map<String, dynamic> features;
  final List<WorkspaceSummary> workspaces;
  final DateTime resolvedAt;

  const Entitlements({
    required this.subscription,
    required this.features,
    required this.workspaces,
    required this.resolvedAt,
  });

  /// El estado de partida antes de que el servidor conteste. Deliberadamente
  /// generoso con lo que Free ya incluye: mientras carga, escribir nunca se
  /// bloquea. Lo de pago se muestra cerrado hasta que el servidor confirme.
  factory Entitlements.fallback() => Entitlements(
        subscription: SubscriptionState.free,
        features: const {
          'atelier.projects.unlimited': true,
          'atelier.worldbuilding': true,
          'atelier.version_history.basic': true,
          'atelier.collaboration': true,
          'atelier.comments': true,
          'atelier.export.markdown': true,
          'atelier.export.txt': true,
          'atelier.export.json': true,
          'atelier.publishing.submissions': true,
        },
        workspaces: const [],
        resolvedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool has(String featureKey) {
    final value = features[featureKey];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }

  /// El tope de un derecho numérico. -1 significa ilimitado; quien llame debe
  /// tratarlo, y por eso no se traduce aquí a un número enorme.
  int limit(String featureKey) {
    final value = features[featureKey];
    if (value is num) return value.toInt();
    if (value is bool) return value ? kUnlimited : 0;
    return 0;
  }

  bool isUnlimited(String featureKey) => limit(featureKey) == kUnlimited;

  WorkspaceSummary? workspaceById(String id) {
    for (final workspace in workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  factory Entitlements.fromMap(Map<String, dynamic> map) {
    return Entitlements(
      subscription: SubscriptionState.fromMap(_jsonMap(map['plan'])),
      features: _jsonMap(map['features']),
      workspaces: (map['workspaces'] as List? ?? const [])
          .map((row) => WorkspaceSummary.fromMap(_jsonMap(row)))
          .toList(),
      resolvedAt: _date(map['resolved_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'plan': subscription.toMap(),
        'features': features,
        'workspaces': workspaces.map((w) => w.toMap()).toList(),
        'resolved_at': resolvedAt.toIso8601String(),
      };
}

class WorkspaceSummary {
  final String id;
  final String slug;
  final String name;
  final String planCode;
  final String status;
  final String roleKey;
  final bool isOwner;
  final bool isBillingOwner;
  final List<String> capabilities;

  const WorkspaceSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.planCode,
    required this.status,
    required this.roleKey,
    required this.isOwner,
    required this.isBillingOwner,
    required this.capabilities,
  });

  bool can(String capability) => capabilities.contains(capability);

  factory WorkspaceSummary.fromMap(Map<String, dynamic> map) {
    return WorkspaceSummary(
      id: map['id'] as String,
      slug: map['slug'] as String? ?? '',
      name: map['name'] as String? ?? '',
      planCode: map['plan_code'] as String? ?? 'free',
      status: map['status'] as String? ?? 'active',
      roleKey: map['role_key'] as String? ?? 'viewer',
      isOwner: map['is_owner'] as bool? ?? false,
      isBillingOwner: map['is_billing_owner'] as bool? ?? false,
      capabilities: _stringList(map['capabilities']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'slug': slug,
        'name': name,
        'plan_code': planCode,
        'status': status,
        'role_key': roleKey,
        'is_owner': isOwner,
        'is_billing_owner': isBillingOwner,
        'capabilities': capabilities,
      };
}

/// Consumo de almacenamiento y recuentos de uso.
class UsageSnapshot {
  final int bytesUsed;
  final int bytesLimit;
  final int objectsCount;

  /// Lo que de verdad hay: proyectos, colaboradores del proyecto más poblado,
  /// automatizaciones encendidas, versiones y miembros del espacio. Los calcula
  /// el servidor; enseñar un cero inventado en una pantalla de consumo sería
  /// peor que no enseñar nada.
  final Map<String, int> counts;

  final Map<String, int> metrics;

  const UsageSnapshot({
    required this.bytesUsed,
    required this.bytesLimit,
    required this.objectsCount,
    this.counts = const {},
    this.metrics = const {},
  });

  static const empty = UsageSnapshot(
    bytesUsed: 0,
    bytesLimit: 0,
    objectsCount: 0,
  );

  int count(String key) => counts[key] ?? 0;

  bool get isUnlimited => bytesLimit == kUnlimited;

  double get fraction {
    if (isUnlimited || bytesLimit <= 0) return 0;
    return (bytesUsed / bytesLimit).clamp(0.0, 1.0);
  }

  int get percentUsed => (fraction * 100).round();

  /// El aviso discreto empieza en el 80 %, el importante en el 95 %.
  bool get isNearLimit => !isUnlimited && percentUsed >= 80;
  bool get isCritical => !isUnlimited && percentUsed >= 95;
  bool get isFull => !isUnlimited && bytesUsed >= bytesLimit;

  int get bytesRemaining =>
      isUnlimited ? kUnlimited : (bytesLimit - bytesUsed).clamp(0, bytesLimit);

  factory UsageSnapshot.fromMap(Map<String, dynamic> map) {
    final storage = _jsonMap(map['storage']);

    Map<String, int> ints(dynamic raw) => _jsonMap(raw).map(
          (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
        );

    return UsageSnapshot(
      bytesUsed: (storage['bytes_used'] as num?)?.toInt() ?? 0,
      bytesLimit: (storage['bytes_limit'] as num?)?.toInt() ?? 0,
      objectsCount: (storage['objects_count'] as num?)?.toInt() ?? 0,
      counts: ints(map['counts']),
      metrics: ints(map['metrics']),
    );
  }
}

class BillingTransaction {
  final String id;
  final String status;
  final String currency;
  final int amount;
  final String description;
  final String? invoiceUrl;
  final String? receiptUrl;
  final DateTime occurredAt;

  const BillingTransaction({
    required this.id,
    required this.status,
    required this.currency,
    required this.amount,
    required this.description,
    this.invoiceUrl,
    this.receiptUrl,
    required this.occurredAt,
  });

  double get value => amount / 100;
  bool get isPaid => status == 'paid';

  factory BillingTransaction.fromMap(Map<String, dynamic> map) {
    return BillingTransaction(
      id: map['id'] as String,
      status: map['status'] as String? ?? 'pending',
      currency: map['currency'] as String? ?? 'MXN',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      description: map['description'] as String? ?? '',
      invoiceUrl: map['invoice_url'] as String?,
      receiptUrl: map['receipt_url'] as String?,
      occurredAt: _date(map['occurred_at']) ?? DateTime.now(),
    );
  }
}

class AddonOffer {
  final String key;
  final String name;
  final String description;
  final String scope;
  final bool isStackable;
  final int? maxQuantity;
  final int sortOrder;
  final List<PlanPrice> prices;

  const AddonOffer({
    required this.key,
    required this.name,
    required this.description,
    required this.scope,
    required this.isStackable,
    required this.maxQuantity,
    required this.sortOrder,
    required this.prices,
  });

  factory AddonOffer.fromMap(
    Map<String, dynamic> map, {
    List<PlanPrice> prices = const [],
  }) {
    return AddonOffer(
      key: map['key'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      scope: map['scope'] as String? ?? 'user',
      isStackable: map['is_stackable'] as bool? ?? true,
      maxQuantity: (map['max_quantity'] as num?)?.toInt(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      prices: prices,
    );
  }
}

/// Una versión del proyecto, con el aviso de si el plan permite volver a ella.
/// Las que quedan fuera de la ventana NO se borran nunca: se ven, se exportan
/// y esperan.
class AtelierVersionEntry {
  final String id;
  final String label;
  final String description;
  final String kind;
  final int wordCount;
  final int nodeCount;
  final bool hasSnapshot;
  final bool restorable;
  final DateTime createdAt;

  const AtelierVersionEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.kind,
    required this.wordCount,
    required this.nodeCount,
    required this.hasSnapshot,
    required this.restorable,
    required this.createdAt,
  });

  factory AtelierVersionEntry.fromMap(Map<String, dynamic> map) {
    return AtelierVersionEntry(
      id: map['id'] as String,
      label: map['label'] as String? ?? 'Versión',
      description: map['description'] as String? ?? '',
      kind: map['kind'] as String? ?? 'manual',
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
      nodeCount: (map['node_count'] as num?)?.toInt() ?? 0,
      hasSnapshot: map['has_snapshot'] as bool? ?? false,
      restorable: map['restorable'] as bool? ?? false,
      createdAt: _date(map['created_at']) ?? DateTime.now(),
    );
  }
}

// ─── Utilidades de lectura ───────────────────────────────────────────────────

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is List) return decoded.map((item) => item.toString()).toList();
  }
  return const [];
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
