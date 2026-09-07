// La frontera entre Corvus y quien cobra.
//
// Corvus no sabe de Stripe. Sabe de "crear un cobro recurrente", "abrir el
// portal del cliente", "cancelar al final del periodo" y "leer un aviso
// firmado". Un proveedor nuevo implementa esta interfaz y el resto de la
// aplicación no se entera: por eso Mercado Pago puede entrar más tarde sin
// tocar ni el esquema ni Flutter.

export type ProviderId = "stripe" | "mercadopago";

export type SubscriptionStatus =
  | "free"
  | "trialing"
  | "active"
  | "past_due"
  | "canceled"
  | "incomplete"
  | "expired";

export interface CheckoutRequest {
  userId: string;
  email: string | null;
  customerId: string | null;
  /** Identificador del precio en el proveedor, no el nuestro. */
  providerPriceId: string;
  planCode: string;
  priceId: string;
  workspaceId: string | null;
  successUrl: string;
  cancelUrl: string;
  trialDays: number;
  couponCode: string | null;
}

export interface CheckoutSession {
  url: string;
  providerSessionId: string;
  customerId: string | null;
}

/** Estado de una suscripción tal y como lo entiende Corvus. */
export interface NormalizedSubscription {
  providerSubscriptionId: string;
  providerCustomerId: string | null;
  providerPriceId: string | null;
  status: SubscriptionStatus;
  quantity: number;
  currentPeriodStart: string | null;
  currentPeriodEnd: string | null;
  cancelAtPeriodEnd: boolean;
  canceledAt: string | null;
  trialStart: string | null;
  trialEnd: string | null;
  endedAt: string | null;
  /** Lo que el proveedor devuelve de la metadata que enviamos al crear. */
  metadata: Record<string, string>;
}

export interface NormalizedTransaction {
  providerTransactionId: string;
  providerCustomerId: string | null;
  providerSubscriptionId: string | null;
  status: "pending" | "paid" | "failed" | "refunded" | "void";
  currency: string;
  amount: number;
  description: string;
  invoiceUrl: string | null;
  receiptUrl: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  occurredAt: string;
}

export interface ProviderEvent {
  id: string;
  type: string;
  payload: unknown;
  subscription?: NormalizedSubscription;
  transaction?: NormalizedTransaction;
}

export class ProviderError extends Error {
  constructor(readonly reasonCode: string, message: string) {
    super(message);
  }
}

export interface BillingProvider {
  readonly id: ProviderId;

  /** Si faltan secretos, la app lo dice en vez de fallar a medio cobro. */
  isConfigured(): boolean;

  ensureCustomer(
    userId: string,
    email: string | null,
    existing: string | null,
  ): Promise<string>;

  createCheckout(request: CheckoutRequest): Promise<CheckoutSession>;

  createPortalSession(
    customerId: string,
    returnUrl: string,
  ): Promise<{ url: string }>;

  cancelSubscription(
    providerSubscriptionId: string,
    atPeriodEnd: boolean,
  ): Promise<NormalizedSubscription>;

  reactivateSubscription(
    providerSubscriptionId: string,
  ): Promise<NormalizedSubscription>;

  changePlan(
    providerSubscriptionId: string,
    newProviderPriceId: string,
  ): Promise<NormalizedSubscription>;

  fetchSubscription(
    providerSubscriptionId: string,
  ): Promise<NormalizedSubscription | null>;

  /** Devuelve null si la firma no valida: sin firma no hay evento. */
  parseWebhook(rawBody: string, signature: string | null): Promise<ProviderEvent | null>;
}
