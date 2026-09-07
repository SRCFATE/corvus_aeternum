// Mercado Pago — plaza reservada, no implementación.
//
// Está aquí para que la abstracción demuestre que sirve: la aplicación pide
// `providerFor('mercadopago')` y recibe algo con la forma correcta, que
// responde BILLING_PROVIDER_NOT_CONFIGURED en vez de romperse. Cuando llegue
// el momento, se rellenan estos métodos contra la API de Preapproval y no hay
// que tocar ni el esquema, ni las RPC, ni Flutter.
//
// Lo que hará falta: MERCADOPAGO_ACCESS_TOKEN, el endpoint de preapproval para
// crear la suscripción, /preapproval/{id} para leerla y cancelarla, y la
// verificación de la firma `x-signature` de la notificación.

import {
  BillingProvider,
  CheckoutRequest,
  CheckoutSession,
  NormalizedSubscription,
  ProviderError,
  ProviderEvent,
} from "./types.ts";

const noEstaListo = (): never => {
  throw new ProviderError(
    "BILLING_PROVIDER_NOT_CONFIGURED",
    "Mercado Pago aún no está implementado como proveedor de cobro.",
  );
};

export class MercadoPagoBillingProvider implements BillingProvider {
  readonly id = "mercadopago" as const;

  isConfigured(): boolean {
    return false;
  }

  ensureCustomer(): Promise<string> {
    return Promise.resolve(noEstaListo());
  }

  createCheckout(_request: CheckoutRequest): Promise<CheckoutSession> {
    return Promise.resolve(noEstaListo());
  }

  createPortalSession(): Promise<{ url: string }> {
    return Promise.resolve(noEstaListo());
  }

  cancelSubscription(): Promise<NormalizedSubscription> {
    return Promise.resolve(noEstaListo());
  }

  reactivateSubscription(): Promise<NormalizedSubscription> {
    return Promise.resolve(noEstaListo());
  }

  changePlan(): Promise<NormalizedSubscription> {
    return Promise.resolve(noEstaListo());
  }

  fetchSubscription(): Promise<NormalizedSubscription | null> {
    return Promise.resolve(null);
  }

  parseWebhook(): Promise<ProviderEvent | null> {
    return Promise.resolve(null);
  }
}
