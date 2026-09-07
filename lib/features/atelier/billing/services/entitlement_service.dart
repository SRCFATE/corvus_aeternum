import '../domain/billing_models.dart';
import '../domain/feature_keys.dart';

/// Por qué una acción no está disponible. Se distingue del derecho ausente
/// —«esto es de Professional»— al tope alcanzado —«ya usaste los 10»—, porque
/// la respuesta del artista es distinta en cada caso y la interfaz debe
/// decirle la verdad concreta.
enum GateReason {
  allowed,

  /// El plan no incluye la función.
  notIncluded,

  /// La incluye, pero ya se llegó al número contratado.
  limitReached,

  /// Espacio agotado. Lo ya guardado sigue intacto; solo no entra más.
  quotaExceeded,
}

class EntitlementCheck {
  final String featureKey;
  final GateReason reason;
  final int limit;
  final int used;

  const EntitlementCheck({
    required this.featureKey,
    required this.reason,
    this.limit = 0,
    this.used = 0,
  });

  bool get allowed => reason == GateReason.allowed;
  bool get isUnlimited => limit == kUnlimited;

  int get remaining =>
      isUnlimited ? kUnlimited : (limit - used).clamp(0, limit);
}

/// El único sitio donde se decide, en el cliente, si una función se ofrece.
///
/// Es puro a propósito: recibe un retrato de los derechos y responde. No pide
/// nada a la red, no guarda estado y no notifica a nadie, así que se puede
/// probar con una tabla de casos y sin Supabase delante.
///
/// Y lo más importante: esto NO es la seguridad. Un cliente adulterado puede
/// hacer que `canUse()` devuelva `true` para lo que quiera. Por eso cada
/// función de pago vuelve a comprobarse en Postgres —trigger, política o RPC—
/// y lo de aquí solo sirve para no ofrecer un botón que va a fallar.
class EntitlementService {
  final Entitlements entitlements;
  final Map<String, bool> flags;
  final UsageSnapshot usage;

  const EntitlementService({
    required this.entitlements,
    this.flags = const {},
    this.usage = UsageSnapshot.empty,
  });

  SubscriptionState get subscription => entitlements.subscription;
  String get planCode => subscription.planCode;

  bool hasEntitlement(String featureKey) => entitlements.has(featureKey);

  int getLimit(String featureKey) => entitlements.limit(featureKey);

  bool isUnlimited(String featureKey) => entitlements.isUnlimited(featureKey);

  bool isFlagEnabled(String flagKey) => flags[flagKey] == true;

  /// ¿Se puede usar esto ahora mismo? Para un derecho de sí/no basta con
  /// tenerlo; para uno con tope hay que decirle cuántos van consumidos.
  EntitlementCheck canUse(String featureKey, {int currentCount = 0}) {
    final value = entitlements.features[featureKey];

    if (value is bool) {
      return EntitlementCheck(
        featureKey: featureKey,
        reason: value ? GateReason.allowed : GateReason.notIncluded,
      );
    }

    if (value is num) {
      final limit = value.toInt();

      if (limit == kUnlimited) {
        return EntitlementCheck(
          featureKey: featureKey,
          reason: GateReason.allowed,
          limit: kUnlimited,
          used: currentCount,
        );
      }

      // Cero no es «llegaste al tope»: es que el plan no lo trae.
      if (limit <= 0) {
        return EntitlementCheck(
          featureKey: featureKey,
          reason: GateReason.notIncluded,
          limit: limit,
          used: currentCount,
        );
      }

      return EntitlementCheck(
        featureKey: featureKey,
        reason: currentCount < limit
            ? GateReason.allowed
            : GateReason.limitReached,
        limit: limit,
        used: currentCount,
      );
    }

    return EntitlementCheck(
      featureKey: featureKey,
      reason: GateReason.notIncluded,
    );
  }

  /// El sitio para un archivo nuevo. Rebasar la cuota impide subir, nunca
  /// borra ni bloquea lo ya guardado.
  EntitlementCheck checkQuota({int incomingBytes = 0}) {
    if (usage.isUnlimited) {
      return const EntitlementCheck(
        featureKey: AtelierFeature.storageMaxBytes,
        reason: GateReason.allowed,
        limit: kUnlimited,
      );
    }

    final fits = usage.bytesUsed + incomingBytes <= usage.bytesLimit;

    return EntitlementCheck(
      featureKey: AtelierFeature.storageMaxBytes,
      reason: fits ? GateReason.allowed : GateReason.quotaExceeded,
      limit: usage.bytesLimit,
      used: usage.bytesUsed,
    );
  }

  UsageSnapshot getUsage() => usage;

  /// Escribir jamás se cierra por no pagar. Esta lista es la promesa del
  /// producto hecha código: si algún día alguien intenta poner una puerta
  /// delante de crear un capítulo, tendrá que borrar esto primero.
  static const protectedFeatures = <String>{
    AtelierFeature.projectsUnlimited,
    AtelierFeature.worldbuilding,
    AtelierFeature.versionHistoryBasic,
    AtelierFeature.exportMarkdown,
    AtelierFeature.exportTxt,
    AtelierFeature.exportJson,
  };

  static bool isProtected(String featureKey) =>
      protectedFeatures.contains(featureKey);

  /// El plan mínimo que incluye un derecho, para poder decir «esto viene con
  /// Professional» sin cablear el nombre del plan en cada pantalla.
  static String planForFeature(String featureKey) {
    const teamsOnly = <String>{
      AtelierFeature.workspace,
      AtelierFeature.workspacesMax,
      AtelierFeature.workspaceSeatsMax,
      AtelierFeature.rolesCustom,
      AtelierFeature.auditLog,
    };

    return teamsOnly.contains(featureKey)
        ? PlanCode.teams
        : PlanCode.professional;
  }
}
