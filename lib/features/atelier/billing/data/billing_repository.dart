import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/rpc_error.dart';
import '../../../../core/supabase_config.dart';
import '../domain/billing_models.dart';

/// El catálogo comercial y las acciones sobre la suscripción.
///
/// El catálogo se lee de tablas —es público y cacheable—. Todo lo que mueve
/// dinero pasa por Edge Functions, porque las claves del proveedor no pueden
/// vivir en un cliente que cualquiera puede descompilar.
class BillingRepository {
  /// Planes con sus precios, listos para pintar la pantalla de Planes. Se lee
  /// sin sesión a propósito: quien evalúa Corvus antes de registrarse merece
  /// saber lo que cuesta.
  Future<List<AtelierPlan>> fetchPlans() async {
    final planRows = await supabase
        .from('plans')
        .select()
        .eq('is_public', true)
        .order('sort_order');

    final priceRows = await supabase
        .from('billing_prices')
        .select('*, billing_products!inner(plan_code, kind, is_active)')
        .eq('billing_products.kind', 'plan')
        .eq('billing_products.is_active', true)
        .order('sort_order');

    final pricesByPlan = <String, List<PlanPrice>>{};
    for (final row in priceRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final product = Map<String, dynamic>.from(
        map['billing_products'] as Map? ?? const {},
      );
      final planCode = product['plan_code'] as String?;
      if (planCode == null) continue;
      pricesByPlan.putIfAbsent(planCode, () => []).add(PlanPrice.fromMap(map));
    }

    return (planRows as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return AtelierPlan.fromMap(
            map,
            prices: pricesByPlan[map['code']] ?? const [],
          );
        })
        .toList();
  }

  Future<List<AddonOffer>> fetchAddons() async {
    final addonRows = await supabase
        .from('atelier_addons')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    final priceRows = await supabase
        .from('billing_prices')
        .select('*, billing_products!inner(addon_key, kind, is_active)')
        .eq('billing_products.kind', 'addon')
        .eq('billing_products.is_active', true)
        .order('sort_order');

    final pricesByAddon = <String, List<PlanPrice>>{};
    for (final row in priceRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final product = Map<String, dynamic>.from(
        map['billing_products'] as Map? ?? const {},
      );
      final key = product['addon_key'] as String?;
      if (key == null) continue;
      pricesByAddon.putIfAbsent(key, () => []).add(PlanPrice.fromMap(map));
    }

    return (addonRows as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return AddonOffer.fromMap(
            map,
            prices: pricesByAddon[map['key']] ?? const [],
          );
        })
        .toList();
  }

  Future<List<BillingTransaction>> fetchTransactions({
    String? workspaceId,
    int limit = 24,
  }) async {
    var query = supabase.from('billing_transactions').select();

    query = workspaceId == null
        ? query.isFilter('workspace_id', null)
        : query.eq('workspace_id', workspaceId);

    final rows = await query.order('occurred_at', ascending: false).limit(limit);

    return (rows as List)
        .map((row) =>
            BillingTransaction.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Add-ons ya comprados y vigentes, para no volver a ofrecer lo que ya se
  /// tiene.
  Future<List<String>> fetchActiveAddonKeys({String? workspaceId}) async {
    var query = supabase
        .from('atelier_purchases')
        .select('addon_key')
        .eq('status', 'active');

    query = workspaceId == null
        ? query.isFilter('workspace_id', null)
        : query.eq('workspace_id', workspaceId);

    final rows = await query;

    return (rows as List)
        .map((row) => (row as Map)['addon_key'] as String?)
        .whereType<String>()
        .toList();
  }

  // ─── Acciones que mueven dinero ────────────────────────────────────────────

  /// Abre el cobro y devuelve la URL a la que hay que llevar al artista.
  Future<String> startCheckout({
    required String priceId,
    String? workspaceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final response = await _invoke('billing-checkout', {
      'price_id': priceId,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (successUrl != null) 'success_url': successUrl,
      if (cancelUrl != null) 'cancel_url': cancelUrl,
    });

    return response['url'] as String;
  }

  Future<String> openPortal({String? workspaceId, String? returnUrl}) async {
    final response = await _invoke('billing-portal', {
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (returnUrl != null) 'return_url': returnUrl,
    });

    return response['url'] as String;
  }

  /// Cancelar, reactivar, cambiar de plan o resincronizar contra el proveedor.
  /// Devuelve el estado tal y como quedó, no el que pedimos.
  Future<Map<String, dynamic>> manageSubscription({
    required String action,
    String? workspaceId,
    String? priceId,
  }) {
    return _invoke('billing-manage', {
      'action': action,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (priceId != null) 'price_id': priceId,
    });
  }

  /// Las Edge Functions responden con el mismo contrato que las RPC del
  /// archivo, así que un fallo se traduce a la misma excepción y el mismo
  /// mensaje en la voz de Corvus.
  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await supabase.functions.invoke(name, body: body);
      final data = response.data;

      if (data is! Map) {
        throw const CorvusRpcException('BILLING_UNEXPECTED_RESPONSE');
      }

      return unwrapRpc(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['reason_code'] is String) {
        throw CorvusRpcException(
          details['reason_code'] as String,
          Map<String, dynamic>.from(details),
        );
      }
      throw const CorvusRpcException('BILLING_REQUEST_FAILED');
    }
  }
}
