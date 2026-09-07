// Stripe, hablado directamente por HTTP.
//
// Se usa la API REST en vez del SDK: la API de Stripe es estable y
// form-encoded, y evitar la dependencia mantiene el arranque en frío corto y
// el despliegue reproducible. La firma del webhook se verifica a mano con Web
// Crypto, comparando en tiempo constante.

import {
  BillingProvider,
  CheckoutRequest,
  CheckoutSession,
  NormalizedSubscription,
  NormalizedTransaction,
  ProviderError,
  ProviderEvent,
  SubscriptionStatus,
} from "./types.ts";

const API = "https://api.stripe.com/v1";

const env = (k: string) => Deno.env.get(k)?.trim() || undefined;

const iso = (seconds: unknown): string | null =>
  typeof seconds === "number" && seconds > 0
    ? new Date(seconds * 1000).toISOString()
    : null;

/** Stripe habla en formulario, incluidas las estructuras anidadas. */
function encode(
  value: unknown,
  prefix = "",
  out: URLSearchParams = new URLSearchParams(),
): URLSearchParams {
  if (value === null || value === undefined) return out;

  if (Array.isArray(value)) {
    value.forEach((item, i) => encode(item, `${prefix}[${i}]`, out));
    return out;
  }

  if (typeof value === "object") {
    for (const [key, inner] of Object.entries(value as object)) {
      encode(inner, prefix ? `${prefix}[${key}]` : key, out);
    }
    return out;
  }

  out.append(prefix, String(value));
  return out;
}

/**
 * Corvus y Stripe no nombran igual los estados. `unpaid` se trata como
 * `past_due` a propósito: son el mismo problema —un cobro que no entró— y el
 * archivo responde igual a los dos, dando acceso y avisando.
 */
function mapStatus(stripeStatus: string): SubscriptionStatus {
  switch (stripeStatus) {
    case "trialing":
      return "trialing";
    case "active":
      return "active";
    case "past_due":
    case "unpaid":
      return "past_due";
    case "canceled":
      return "canceled";
    case "incomplete":
      return "incomplete";
    case "incomplete_expired":
      return "expired";
    default:
      return "incomplete";
  }
}

// deno-lint-ignore no-explicit-any
function normalizeSubscription(sub: any): NormalizedSubscription {
  const item = sub?.items?.data?.[0];

  return {
    providerSubscriptionId: sub.id,
    providerCustomerId: typeof sub.customer === "string" ? sub.customer : null,
    providerPriceId: item?.price?.id ?? null,
    status: mapStatus(sub.status ?? ""),
    quantity: Number(item?.quantity ?? 1) || 1,
    currentPeriodStart: iso(sub.current_period_start),
    currentPeriodEnd: iso(sub.current_period_end),
    cancelAtPeriodEnd: Boolean(sub.cancel_at_period_end),
    canceledAt: iso(sub.canceled_at),
    trialStart: iso(sub.trial_start),
    trialEnd: iso(sub.trial_end),
    endedAt: iso(sub.ended_at),
    metadata: (sub.metadata ?? {}) as Record<string, string>,
  };
}

// deno-lint-ignore no-explicit-any
function normalizeInvoice(invoice: any): NormalizedTransaction {
  const paid = invoice.status === "paid";

  return {
    providerTransactionId: invoice.id,
    providerCustomerId: typeof invoice.customer === "string"
      ? invoice.customer
      : null,
    providerSubscriptionId: typeof invoice.subscription === "string"
      ? invoice.subscription
      : null,
    status: paid
      ? "paid"
      : invoice.status === "void"
      ? "void"
      : invoice.attempt_count > 0
      ? "failed"
      : "pending",
    currency: String(invoice.currency ?? "mxn").toUpperCase(),
    amount: Number(invoice.amount_paid ?? invoice.amount_due ?? 0),
    description: invoice.lines?.data?.[0]?.description ??
      invoice.description ?? "Suscripción Atelier",
    invoiceUrl: invoice.hosted_invoice_url ?? null,
    receiptUrl: invoice.invoice_pdf ?? null,
    periodStart: iso(invoice.period_start),
    periodEnd: iso(invoice.period_end),
    occurredAt: iso(invoice.created) ?? new Date().toISOString(),
  };
}

/** Comparación en tiempo constante: una comparación normal filtra la firma. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export class StripeBillingProvider implements BillingProvider {
  readonly id = "stripe" as const;

  private get key(): string | undefined {
    return env("STRIPE_SECRET_KEY");
  }

  isConfigured(): boolean {
    return Boolean(this.key);
  }

  private async call(
    path: string,
    method: "GET" | "POST" | "DELETE" = "POST",
    body?: unknown,
    idempotencyKey?: string,
  ): Promise<Record<string, unknown>> {
    const key = this.key;
    if (!key) {
      throw new ProviderError("BILLING_PROVIDER_NOT_CONFIGURED", "Falta STRIPE_SECRET_KEY");
    }

    const headers: Record<string, string> = {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Stripe-Version": "2024-06-20",
    };
    if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;

    const res = await fetch(`${API}${path}`, {
      method,
      headers,
      body: method === "POST" && body ? encode(body).toString() : undefined,
    });

    const parsed = await res.json();

    if (!res.ok) {
      const message = parsed?.error?.message ?? `Stripe ${res.status}`;
      console.error("Stripe error:", res.status, message);
      throw new ProviderError("BILLING_PROVIDER_ERROR", message);
    }

    return parsed;
  }

  async ensureCustomer(
    userId: string,
    email: string | null,
    existing: string | null,
  ): Promise<string> {
    if (existing) return existing;

    const customer = await this.call("/customers", "POST", {
      email: email ?? undefined,
      metadata: { corvus_user_id: userId },
    }, `customer:${userId}`);

    return customer.id as string;
  }

  async createCheckout(request: CheckoutRequest): Promise<CheckoutSession> {
    const session = await this.call("/checkout/sessions", "POST", {
      mode: "subscription",
      customer: request.customerId ?? undefined,
      customer_email: request.customerId ? undefined : request.email ?? undefined,
      success_url: request.successUrl,
      cancel_url: request.cancelUrl,
      line_items: [{ price: request.providerPriceId, quantity: 1 }],
      allow_promotion_codes: true,
      client_reference_id: request.userId,
      // Esta metadata es la que devuelve el webhook: sin ella no sabríamos a
      // qué cuenta ni a qué workspace corresponde el cobro.
      metadata: {
        corvus_user_id: request.userId,
        corvus_plan_code: request.planCode,
        corvus_price_id: request.priceId,
        corvus_workspace_id: request.workspaceId ?? "",
      },
      subscription_data: {
        trial_period_days: request.trialDays > 0 ? request.trialDays : undefined,
        metadata: {
          corvus_user_id: request.userId,
          corvus_plan_code: request.planCode,
          corvus_price_id: request.priceId,
          corvus_workspace_id: request.workspaceId ?? "",
        },
      },
    });

    return {
      url: session.url as string,
      providerSessionId: session.id as string,
      customerId: (session.customer as string) ?? request.customerId,
    };
  }

  async createPortalSession(
    customerId: string,
    returnUrl: string,
  ): Promise<{ url: string }> {
    const session = await this.call("/billing_portal/sessions", "POST", {
      customer: customerId,
      return_url: returnUrl,
    });

    return { url: session.url as string };
  }

  async cancelSubscription(
    providerSubscriptionId: string,
    atPeriodEnd: boolean,
  ): Promise<NormalizedSubscription> {
    // Cancelar al final del periodo es el camino por defecto: quien ya pagó el
    // mes lo usa entero. La baja inmediata existe para casos de soporte.
    const sub = atPeriodEnd
      ? await this.call(`/subscriptions/${providerSubscriptionId}`, "POST", {
        cancel_at_period_end: true,
      })
      : await this.call(`/subscriptions/${providerSubscriptionId}`, "DELETE");

    return normalizeSubscription(sub);
  }

  async reactivateSubscription(
    providerSubscriptionId: string,
  ): Promise<NormalizedSubscription> {
    const sub = await this.call(
      `/subscriptions/${providerSubscriptionId}`,
      "POST",
      { cancel_at_period_end: false },
    );

    return normalizeSubscription(sub);
  }

  async changePlan(
    providerSubscriptionId: string,
    newProviderPriceId: string,
  ): Promise<NormalizedSubscription> {
    const current = await this.call(
      `/subscriptions/${providerSubscriptionId}`,
      "GET",
    );

    // deno-lint-ignore no-explicit-any
    const itemId = (current as any)?.items?.data?.[0]?.id;
    if (!itemId) {
      throw new ProviderError("BILLING_SUBSCRIPTION_ITEM_MISSING", "Sin ítem que cambiar");
    }

    const sub = await this.call(
      `/subscriptions/${providerSubscriptionId}`,
      "POST",
      {
        items: [{ id: itemId, price: newProviderPriceId }],
        // El prorrateo hace que subir de plan a mitad de mes cobre solo la
        // diferencia, y que bajar deje saldo a favor.
        proration_behavior: "create_prorations",
      },
    );

    return normalizeSubscription(sub);
  }

  async fetchSubscription(
    providerSubscriptionId: string,
  ): Promise<NormalizedSubscription | null> {
    try {
      const sub = await this.call(
        `/subscriptions/${providerSubscriptionId}`,
        "GET",
      );
      return normalizeSubscription(sub);
    } catch {
      return null;
    }
  }

  async parseWebhook(
    rawBody: string,
    signature: string | null,
  ): Promise<ProviderEvent | null> {
    const secret = env("STRIPE_WEBHOOK_SECRET");
    if (!secret || !signature) return null;

    const parts = Object.fromEntries(
      signature.split(",").map((p) => p.split("=", 2) as [string, string]),
    );
    const timestamp = parts["t"];
    const provided = parts["v1"];
    if (!timestamp || !provided) return null;

    // Un aviso viejo reproducido es un ataque de repetición: cinco minutos.
    const age = Math.abs(Date.now() / 1000 - Number(timestamp));
    if (!Number.isFinite(age) || age > 300) {
      console.error("Webhook fuera de ventana temporal:", age);
      return null;
    }

    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const mac = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(`${timestamp}.${rawBody}`),
    );
    const expected = Array.from(new Uint8Array(mac))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (!timingSafeEqual(expected, provided)) {
      console.error("Firma de webhook inválida");
      return null;
    }

    const event = JSON.parse(rawBody);
    const object = event?.data?.object;
    const result: ProviderEvent = {
      id: event.id,
      type: event.type,
      payload: event,
    };

    if (String(event.type).startsWith("customer.subscription.")) {
      result.subscription = normalizeSubscription(object);
    }

    if (String(event.type).startsWith("invoice.")) {
      result.transaction = normalizeInvoice(object);
      if (typeof object?.subscription === "string") {
        const sub = await this.fetchSubscription(object.subscription);
        if (sub) result.subscription = sub;
      }
    }

    if (event.type === "checkout.session.completed" && object?.subscription) {
      const sub = await this.fetchSubscription(object.subscription as string);
      if (sub) {
        // La metadata de la sesión es la fuente fiable de a quién pertenece.
        sub.metadata = { ...(object.metadata ?? {}), ...sub.metadata };
        result.subscription = sub;
      }
    }

    return result;
  }
}
