import 'package:corvus_aeternum/features/atelier/billing/domain/billing_models.dart';
import 'package:corvus_aeternum/features/atelier/billing/services/usage_service.dart';
import 'package:corvus_aeternum/features/atelier/billing/widgets/billing_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que se le enseña a alguien antes de cobrarle.
///
/// El precio, el ahorro anunciado y el espacio que dice quedar tienen que ser
/// exactos. Un porcentaje de ahorro inventado o un «1.9 GB» mal redondeado no
/// son un fallo de formato: son una cifra falsa en una decisión de compra.
void main() {
  PlanPrice price({
    required String id,
    required int amount,
    required String interval,
  }) {
    return PlanPrice(
      id: id,
      productId: 'atelier_professional',
      provider: 'stripe',
      currency: 'MXN',
      unitAmount: amount,
      interval: interval,
      trialDays: 0,
      isDefault: interval == 'month',
      label: '',
    );
  }

  group('precios', () {
    test('los importes se guardan en centavos y se muestran en pesos', () {
      expect(price(id: 'p', amount: 9900, interval: 'month').amount, 99);
      expect(price(id: 'p', amount: 99000, interval: 'year').amount, 990);
    });

    test('un plan anual se compara por su equivalente mensual', () {
      final anual = price(id: 'p', amount: 99000, interval: 'year');
      expect(anual.monthlyEquivalent, closeTo(82.5, 0.001));
    });
  });

  group('ahorro anual', () {
    AtelierPlan plan(List<PlanPrice> prices) => AtelierPlan(
          code: 'professional',
          name: 'Atelier Professional',
          tagline: '',
          description: '',
          scope: 'user',
          tierRank: 10,
          badge: '',
          isRecommended: true,
          sortOrder: 1,
          highlights: const [],
          prices: prices,
        );

    test('se calcula, no se inventa', () {
      // 99 × 12 = 1188; se pagan 990 → 16,66 % → 17 %.
      final p = plan([
        price(id: 'm', amount: 9900, interval: 'month'),
        price(id: 'y', amount: 99000, interval: 'year'),
      ]);
      expect(p.yearlySavingPercent, 17);
    });

    test('sin las dos modalidades no se anuncia ahorro alguno', () {
      expect(
        plan([price(id: 'm', amount: 9900, interval: 'month')])
            .yearlySavingPercent,
        isNull,
      );
    });

    test('si el anual no ahorra, no se finge que sí', () {
      final p = plan([
        price(id: 'm', amount: 9900, interval: 'month'),
        price(id: 'y', amount: 130000, interval: 'year'),
      ]);
      expect(p.yearlySavingPercent, isNull);
    });
  });

  group('formato de bytes', () {
    test('redondea sin mentir sobre el espacio', () {
      expect(formatBytes(2147483648), '2 GB');
      expect(formatBytes(26843545600), '25 GB');
      expect(formatBytes(107374182400), '100 GB');
      expect(formatBytes(1395864371), '1.3 GB');
      expect(formatBytes(0), '0 MB');
    });

    test('lo ilimitado se dice con palabras, no con un número enorme', () {
      expect(formatBytes(kUnlimited), 'Sin límite');
    });
  });

  group('formato de dinero', () {
    test('separa miles y coloca la moneda detrás', () {
      expect(formatMoney(99, 'MXN'), r'$99 MXN');
      expect(formatMoney(990, 'MXN'), r'$990 MXN');
      expect(formatMoney(1290.5, 'MXN'), r'$1,290.50 MXN');
      expect(formatMoney(2990, 'MXN'), r'$2,990 MXN');
    });
  });

  group('fechas de facturación', () {
    test('se escriben en español sin depender de datos de locale', () {
      expect(formatBillingDate(DateTime(2026, 9, 4)), '4 de septiembre de 2026');
      expect(formatShortDate(DateTime(2026, 1, 15)), '15 ene 2026');
    });
  });

  group('la caché de derechos sobrevive al viaje de ida y vuelta', () {
    test('serializar y volver a leer conserva plan, derechos y workspaces', () {
      final original = Entitlements(
        subscription: SubscriptionState(
          planCode: 'professional',
          status: 'active',
          subscriptionId: 'sub-1',
          currentPeriodEnd: DateTime.utc(2026, 12, 1),
          cancelAtPeriodEnd: true,
        ),
        features: const {
          'atelier.export.pdf': true,
          'atelier.collaborators.max': 10,
          'atelier.storage.max_bytes': 26843545600,
        },
        workspaces: const [
          WorkspaceSummary(
            id: 'w1',
            slug: 'editorial-cuervo',
            name: 'Editorial Cuervo',
            planCode: 'teams',
            status: 'active',
            roleKey: 'editor',
            isOwner: false,
            isBillingOwner: false,
            capabilities: ['project.read', 'project.write'],
          ),
        ],
        resolvedAt: DateTime.utc(2026, 9, 4),
      );

      final round = Entitlements.fromMap(original.toMap());

      expect(round.subscription.planCode, 'professional');
      expect(round.subscription.cancelAtPeriodEnd, isTrue);
      expect(round.subscription.currentPeriodEnd, DateTime.utc(2026, 12, 1));
      expect(round.has('atelier.export.pdf'), isTrue);
      expect(round.limit('atelier.collaborators.max'), 10);
      expect(round.limit('atelier.storage.max_bytes'), 26843545600);
      expect(round.workspaces.single.name, 'Editorial Cuervo');
      expect(round.workspaces.single.can('project.write'), isTrue);
      expect(round.workspaces.single.can('billing.manage'), isFalse);
    });
  });

  group('rutas del bucket de Atelier', () {
    test('el primer segmento decide a qué bolsa de cuota se carga', () {
      expect(
        AtelierStorageService.pathFor(
          projectId: 'p1',
          filename: 'portada.png',
          profileId: 'u1',
        ),
        'u/u1/p1/portada.png',
      );

      expect(
        AtelierStorageService.pathFor(
          projectId: 'p1',
          filename: 'portada.png',
          profileId: 'u1',
          workspaceId: 'w1',
        ),
        'w/w1/p1/portada.png',
      );
    });
  });

  group('lectura de uso', () {
    test('se construye desde la respuesta del servidor', () {
      final usage = UsageSnapshot.fromMap(const {
        'storage': {
          'bytes_used': 1073741824,
          'bytes_limit': 2147483648,
          'objects_count': 12,
        },
        'metrics': {'automations:total': 3},
      });

      expect(usage.bytesUsed, 1073741824);
      expect(usage.percentUsed, 50);
      expect(usage.objectsCount, 12);
      expect(usage.metrics['automations:total'], 3);
      expect(usage.bytesRemaining, 1073741824);
    });
  });
}
