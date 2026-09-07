import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/rpc_error.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';

/// Las operaciones comerciales, sin una sola en widgets.
///
/// Corvus no toca datos de tarjeta: el cobro ocurre en el proveedor y aquí
/// solo se abre la puerta firmada. Esa decisión, además de reducir el
/// cumplimiento normativo a cero, es la razón de que este servicio sea tan
/// corto.
class BillingService {
  final BillingRepository _repository;

  BillingService({BillingRepository? repository})
      : _repository = repository ?? BillingRepository();

  Future<List<AtelierPlan>> loadPlans() => _repository.fetchPlans();

  Future<List<AddonOffer>> loadAddons() => _repository.fetchAddons();

  Future<List<BillingTransaction>> loadTransactions({String? workspaceId}) =>
      _repository.fetchTransactions(workspaceId: workspaceId);

  Future<List<String>> loadActiveAddonKeys({String? workspaceId}) =>
      _repository.fetchActiveAddonKeys(workspaceId: workspaceId);

  /// Lleva al artista al cobro. En web se abre en la misma pestaña para que
  /// el regreso conserve la sesión; en móvil y escritorio, en el navegador.
  Future<void> startCheckout({
    required String priceId,
    String? workspaceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final url = await _repository.startCheckout(
      priceId: priceId,
      workspaceId: workspaceId,
      successUrl: successUrl,
      cancelUrl: cancelUrl,
    );

    await _open(url);
  }

  Future<void> openBillingPortal({
    String? workspaceId,
    String? returnUrl,
  }) async {
    final url = await _repository.openPortal(
      workspaceId: workspaceId,
      returnUrl: returnUrl,
    );

    await _open(url);
  }

  /// Cancela al final del periodo: quien ya pagó el mes lo usa entero, y su
  /// contenido no se toca ni entonces ni después.
  Future<Map<String, dynamic>> cancel({String? workspaceId}) =>
      _repository.manageSubscription(
        action: 'cancel',
        workspaceId: workspaceId,
      );

  Future<Map<String, dynamic>> reactivate({String? workspaceId}) =>
      _repository.manageSubscription(
        action: 'reactivate',
        workspaceId: workspaceId,
      );

  Future<Map<String, dynamic>> changePlan({
    required String priceId,
    String? workspaceId,
  }) =>
      _repository.manageSubscription(
        action: 'change_plan',
        priceId: priceId,
        workspaceId: workspaceId,
      );

  /// Vuelve a preguntarle al proveedor en qué estado está la suscripción. Es
  /// la salida cuando un webhook se perdió.
  Future<Map<String, dynamic>> sync({String? workspaceId}) =>
      _repository.manageSubscription(
        action: 'sync',
        workspaceId: workspaceId,
      );

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);

    // La dirección viene de nuestra propia Edge Function, que a su vez la
    // recibe del proveedor de pagos. Aun así se comprueba el esquema antes de
    // abrirla: en web esto es una navegación de la pestaña actual, y un
    // `javascript:` colado por cualquier eslabón intermedio se ejecutaría con
    // la sesión del artista delante.
    if (uri == null || uri.scheme != 'https') {
      throw const CorvusRpcException('BILLING_UNEXPECTED_RESPONSE');
    }

    final launched = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );

    if (!launched) {
      throw const CorvusRpcException('BILLING_CHECKOUT_FAILED');
    }
  }
}
