import 'package:corvus_aeternum/features/atelier/billing/domain/billing_models.dart';
import 'package:corvus_aeternum/features/atelier/billing/domain/feature_keys.dart';
import 'package:corvus_aeternum/features/atelier/billing/services/entitlement_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// El motor de derechos, visto desde Flutter.
///
/// Estas pruebas fijan la promesa comercial de Atelier en código: qué incluye
/// cada plan, qué no se puede cerrar nunca y cómo se comporta un límite cuando
/// se alcanza. Si alguien cambia la política del producto, aquí se entera.
///
/// Ojo con el alcance: esto comprueba la EVALUACIÓN en cliente, que sirve para
/// no ofrecer botones que van a fallar. La seguridad de verdad está en
/// Postgres y se prueba en `supabase/tests/monetizacion.sql`.
void main() {
  Entitlements build(
    String planCode,
    Map<String, dynamic> features, {
    String status = 'active',
  }) {
    return Entitlements(
      subscription: SubscriptionState(planCode: planCode, status: status),
      features: features,
      workspaces: const [],
      resolvedAt: DateTime.now(),
    );
  }

  // Retratos de los tres planes, con los mismos valores que siembra la
  // migración `billing_catalog_seed`.
  final free = build('free', const {
    AtelierFeature.projectsUnlimited: true,
    AtelierFeature.worldbuilding: true,
    AtelierFeature.versionHistoryBasic: true,
    AtelierFeature.versionHistoryAdvanced: false,
    AtelierFeature.versionHistoryMaxSnapshots: 10,
    AtelierFeature.collaboration: true,
    AtelierFeature.collaboratorsMax: 1,
    AtelierFeature.storageMaxBytes: 2147483648,
    AtelierFeature.exportMarkdown: true,
    AtelierFeature.exportTxt: true,
    AtelierFeature.exportJson: true,
    AtelierFeature.exportPdf: false,
    AtelierFeature.exportDocx: false,
    AtelierFeature.automation: false,
    AtelierFeature.automationsMax: 0,
    AtelierFeature.workspace: false,
    AtelierFeature.workspacesMax: 0,
  });

  final professional = build('professional', const {
    AtelierFeature.projectsUnlimited: true,
    AtelierFeature.worldbuilding: true,
    AtelierFeature.versionHistoryBasic: true,
    AtelierFeature.versionHistoryAdvanced: true,
    AtelierFeature.versionHistoryMaxSnapshots: -1,
    AtelierFeature.collaboration: true,
    AtelierFeature.collaboratorsMax: 10,
    AtelierFeature.storageMaxBytes: 26843545600,
    AtelierFeature.exportMarkdown: true,
    AtelierFeature.exportTxt: true,
    AtelierFeature.exportJson: true,
    AtelierFeature.exportPdf: true,
    AtelierFeature.exportDocx: true,
    AtelierFeature.automation: true,
    AtelierFeature.automationsMax: 25,
    AtelierFeature.workspace: false,
    AtelierFeature.workspacesMax: 0,
  });

  final teams = build('teams', const {
    AtelierFeature.collaboratorsMax: 50,
    AtelierFeature.storageMaxBytes: 107374182400,
    AtelierFeature.workspace: true,
    AtelierFeature.workspacesMax: 3,
    AtelierFeature.workspaceSeatsMax: 25,
    AtelierFeature.rolesCustom: true,
    AtelierFeature.auditLog: true,
    AtelierFeature.exportPdf: true,
  });

  group('Atelier Free crea sin límites', () {
    final service = EntitlementService(entitlements: free);

    test('proyectos, mundos y worldbuilding están incluidos', () {
      expect(service.hasEntitlement(AtelierFeature.projectsUnlimited), isTrue);
      expect(service.hasEntitlement(AtelierFeature.worldbuilding), isTrue);
    });

    test('la portabilidad básica nunca se cobra', () {
      expect(service.hasEntitlement(AtelierFeature.exportMarkdown), isTrue);
      expect(service.hasEntitlement(AtelierFeature.exportTxt), isTrue);
      expect(service.hasEntitlement(AtelierFeature.exportJson), isTrue);
    });

    test('lo profesional se muestra cerrado, no oculto', () {
      final pdf = service.canUse(AtelierFeature.exportPdf);
      expect(pdf.allowed, isFalse);
      expect(pdf.reason, GateReason.notIncluded);
    });

    test('permite un colaborador y avisa al llegar al tope', () {
      expect(
        service.canUse(AtelierFeature.collaboratorsMax, currentCount: 0).allowed,
        isTrue,
      );

      final lleno =
          service.canUse(AtelierFeature.collaboratorsMax, currentCount: 1);
      expect(lleno.allowed, isFalse);
      expect(lleno.reason, GateReason.limitReached);
      expect(lleno.remaining, 0);
    });

    test('un tope de cero no es «llegaste al límite», es «no lo incluye»', () {
      // La diferencia importa: a quien nunca tuvo automatizaciones no se le
      // dice que las agotó.
      final automatizaciones = service.canUse(AtelierFeature.automationsMax);
      expect(automatizaciones.reason, GateReason.notIncluded);
    });
  });

  group('Atelier Professional', () {
    final service = EntitlementService(entitlements: professional);

    test('abre historial avanzado, exportaciones y automatizaciones', () {
      expect(
        service.hasEntitlement(AtelierFeature.versionHistoryAdvanced),
        isTrue,
      );
      expect(service.hasEntitlement(AtelierFeature.exportPdf), isTrue);
      expect(service.hasEntitlement(AtelierFeature.automation), isTrue);
    });

    test('-1 significa ilimitado y no se agota nunca', () {
      expect(
        service.isUnlimited(AtelierFeature.versionHistoryMaxSnapshots),
        isTrue,
      );

      final check = service.canUse(
        AtelierFeature.versionHistoryMaxSnapshots,
        currentCount: 9999,
      );
      expect(check.allowed, isTrue);
      expect(check.remaining, kUnlimited);
    });

    test('no incluye workspaces: eso es Teams', () {
      expect(service.hasEntitlement(AtelierFeature.workspace), isFalse);
      expect(
        EntitlementService.planForFeature(AtelierFeature.workspace),
        PlanCode.teams,
      );
    });
  });

  group('Atelier Teams', () {
    final service = EntitlementService(entitlements: teams);

    test('abre espacios, roles propios y auditoría', () {
      expect(service.hasEntitlement(AtelierFeature.workspace), isTrue);
      expect(service.hasEntitlement(AtelierFeature.rolesCustom), isTrue);
      expect(service.hasEntitlement(AtelierFeature.auditLog), isTrue);
    });

    test('nunca concede menos que Professional', () {
      final pro = EntitlementService(entitlements: professional);
      expect(
        service.getLimit(AtelierFeature.collaboratorsMax),
        greaterThanOrEqualTo(pro.getLimit(AtelierFeature.collaboratorsMax)),
      );
      expect(
        service.getLimit(AtelierFeature.storageMaxBytes),
        greaterThanOrEqualTo(pro.getLimit(AtelierFeature.storageMaxBytes)),
      );
    });
  });

  group('cuota de almacenamiento', () {
    UsageSnapshot usage(int used, int limit) =>
        UsageSnapshot(bytesUsed: used, bytesLimit: limit, objectsCount: 1);

    test('deja subir mientras quepa', () {
      final service = EntitlementService(
        entitlements: free,
        usage: usage(1000, 2000),
      );
      expect(service.checkQuota(incomingBytes: 900).allowed, isTrue);
    });

    test('rechaza lo que no cabe, sin tocar lo guardado', () {
      final service = EntitlementService(
        entitlements: free,
        usage: usage(1900, 2000),
      );

      final check = service.checkQuota(incomingBytes: 500);
      expect(check.allowed, isFalse);
      expect(check.reason, GateReason.quotaExceeded);
      // El uso registrado no cambia: rechazar una subida no borra archivos.
      expect(service.getUsage().bytesUsed, 1900);
    });

    test('con cuota ilimitada nunca se cierra', () {
      final service = EntitlementService(
        entitlements: professional,
        usage: usage(9999999, kUnlimited),
      );
      expect(service.checkQuota(incomingBytes: 999999999).allowed, isTrue);
    });

    test('los avisos escalonan en 80 % y 95 %', () {
      expect(usage(79, 100).isNearLimit, isFalse);
      expect(usage(80, 100).isNearLimit, isTrue);
      expect(usage(94, 100).isCritical, isFalse);
      expect(usage(95, 100).isCritical, isTrue);
      expect(usage(100, 100).isFull, isTrue);
    });
  });

  group('el proceso creativo nunca se cierra por no pagar', () {
    test('la lista blindada cubre crear, construir y llevarse la obra', () {
      // Si alguien intenta poner precio a escribir, tendrá que borrar esta
      // prueba antes, y entonces el cambio será deliberado y visible.
      expect(
        EntitlementService.isProtected(AtelierFeature.projectsUnlimited),
        isTrue,
      );
      expect(
        EntitlementService.isProtected(AtelierFeature.worldbuilding),
        isTrue,
      );
      expect(
        EntitlementService.isProtected(AtelierFeature.versionHistoryBasic),
        isTrue,
      );
      expect(EntitlementService.isProtected(AtelierFeature.exportMarkdown), isTrue);
      expect(EntitlementService.isProtected(AtelierFeature.exportTxt), isTrue);
      expect(EntitlementService.isProtected(AtelierFeature.exportJson), isTrue);
    });

    test('lo blindado sigue abierto incluso en el plan más bajo', () {
      final service = EntitlementService(entitlements: free);
      for (final feature in EntitlementService.protectedFeatures) {
        expect(
          service.hasEntitlement(feature),
          isTrue,
          reason: '$feature debe estar incluido en Free',
        );
      }
    });
  });

  group('estados de suscripción', () {
    test('un cobro rechazado conserva el acceso y pide atención', () {
      const pastDue = SubscriptionState(
        planCode: 'professional',
        status: 'past_due',
      );
      expect(pastDue.needsAttention, isTrue);
      expect(pastDue.isFree, isFalse);
    });

    test('una cancelación programada sigue activa hasta su fecha', () {
      final cancelando = SubscriptionState(
        planCode: 'professional',
        status: 'active',
        cancelAtPeriodEnd: true,
        currentPeriodEnd: DateTime.now().add(const Duration(days: 12)),
      );
      expect(cancelando.isActive, isTrue);
      expect(cancelando.willEnd, isTrue);
    });

    test('el estado de partida es Free, nunca un plan de pago', () {
      final fallback = Entitlements.fallback();
      expect(fallback.subscription.planCode, PlanCode.free);
      // Y mientras carga no bloquea escribir.
      expect(fallback.has(AtelierFeature.projectsUnlimited), isTrue);
      expect(fallback.has(AtelierFeature.exportPdf), isFalse);
    });
  });

  group('sin derechos resueltos', () {
    test('un derecho desconocido se niega, no se asume', () {
      final service = EntitlementService(entitlements: build('free', const {}));
      final check = service.canUse('atelier.feature.inventada');
      expect(check.allowed, isFalse);
      expect(check.reason, GateReason.notIncluded);
    });
  });
}
