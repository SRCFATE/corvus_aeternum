// Traducir lo que dice el proveedor al estado de Corvus.
//
// Es el único sitio donde una suscripción cambia de estado. Lo llaman el
// webhook, la resincronización manual y las acciones del centro de
// facturación, para que las tres lleguen exactamente al mismo resultado.

import { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  NormalizedSubscription,
  NormalizedTransaction,
  ProviderId,
} from "./providers/index.ts";

/**
 * A quién pertenece esta suscripción. Primero la metadata que enviamos al
 * crear el checkout; si falta —una suscripción creada a mano en el panel de
 * Stripe, por ejemplo—, se busca por el cliente.
 */
async function resolveUserId(
  admin: SupabaseClient,
  provider: ProviderId,
  sub: NormalizedSubscription,
): Promise<string | null> {
  const fromMetadata = sub.metadata?.corvus_user_id;
  if (fromMetadata && fromMetadata.length > 0) return fromMetadata;

  if (!sub.providerCustomerId) return null;

  const { data } = await admin
    .from("billing_customers")
    .select("user_id")
    .eq("provider", provider)
    .eq("provider_customer_id", sub.providerCustomerId)
    .maybeSingle();

  return data?.user_id ?? null;
}

/** Qué plan es esto: la metadata manda, el precio decide si no la hay. */
async function resolvePlan(
  admin: SupabaseClient,
  provider: ProviderId,
  sub: NormalizedSubscription,
): Promise<{ planCode: string; priceId: string | null; productId: string | null }> {
  const fromMetadata = sub.metadata?.corvus_plan_code;
  const priceFromMetadata = sub.metadata?.corvus_price_id;

  if (sub.providerPriceId) {
    const { data } = await admin
      .from("billing_prices")
      .select("id, product_id, billing_products(plan_code)")
      .eq("provider", provider)
      .eq("provider_price_id", sub.providerPriceId)
      .maybeSingle();

    if (data) {
      // deno-lint-ignore no-explicit-any
      const planCode = (data as any).billing_products?.plan_code;
      if (planCode) {
        return {
          planCode,
          priceId: data.id as string,
          productId: data.product_id as string,
        };
      }
    }
  }

  if (priceFromMetadata) {
    const { data } = await admin
      .from("billing_prices")
      .select("id, product_id, billing_products(plan_code)")
      .eq("id", priceFromMetadata)
      .maybeSingle();

    if (data) {
      return {
        // deno-lint-ignore no-explicit-any
        planCode: (data as any).billing_products?.plan_code ?? fromMetadata ?? "free",
        priceId: data.id as string,
        productId: data.product_id as string,
      };
    }
  }

  return { planCode: fromMetadata ?? "free", priceId: null, productId: null };
}

const LIVE = ["trialing", "active", "past_due", "incomplete"];

export interface ApplyResult {
  ok: boolean;
  reason?: string;
  userId?: string;
  planCode?: string;
  status?: string;
}

export async function applySubscription(
  admin: SupabaseClient,
  provider: ProviderId,
  sub: NormalizedSubscription,
): Promise<ApplyResult> {
  const userId = await resolveUserId(admin, provider, sub);
  if (!userId) {
    return { ok: false, reason: "SUBSCRIPTION_WITHOUT_OWNER" };
  }

  const workspaceId = sub.metadata?.corvus_workspace_id || null;
  const { planCode, priceId, productId } = await resolvePlan(admin, provider, sub);

  if (sub.providerCustomerId) {
    await admin.from("billing_customers").upsert({
      user_id: userId,
      provider,
      provider_customer_id: sub.providerCustomerId,
    }, { onConflict: "user_id,provider" });
  }

  // Corvus permite una sola suscripción viva por titular. Si el proveedor
  // abrió otra —cambio de plan que crea suscripción nueva, alta duplicada—,
  // la anterior se cierra antes de escribir la nueva: si no, el índice único
  // parcial rechazaría el alta y el cobro quedaría sin reflejar.
  if (LIVE.includes(sub.status)) {
    const stale = admin
      .from("billing_subscriptions")
      .update({ status: "canceled", ended_at: new Date().toISOString() })
      .in("status", LIVE)
      .neq("provider_subscription_id", sub.providerSubscriptionId);

    await (workspaceId
      ? stale.eq("workspace_id", workspaceId)
      : stale.eq("user_id", userId).is("workspace_id", null));
  }

  const row = {
    user_id: userId,
    workspace_id: workspaceId,
    plan_code: planCode,
    product_id: productId,
    price_id: priceId,
    provider,
    provider_subscription_id: sub.providerSubscriptionId,
    status: sub.status,
    quantity: sub.quantity,
    current_period_start: sub.currentPeriodStart,
    current_period_end: sub.currentPeriodEnd,
    cancel_at_period_end: sub.cancelAtPeriodEnd,
    canceled_at: sub.canceledAt,
    trial_start: sub.trialStart,
    trial_end: sub.trialEnd,
    ended_at: sub.endedAt,
    updated_at: new Date().toISOString(),
  };

  const { error } = await admin
    .from("billing_subscriptions")
    .upsert(row, { onConflict: "provider,provider_subscription_id" });

  if (error) {
    console.error("No se pudo guardar la suscripción:", error.message);
    return { ok: false, reason: "SUBSCRIPTION_WRITE_FAILED" };
  }

  // El plan del workspace se refleja en su fila para que la lectura del
  // catálogo no tenga que resolver la suscripción cada vez.
  if (workspaceId) {
    await admin
      .from("atelier_workspaces")
      .update({
        plan_code: LIVE.includes(sub.status) ? planCode : "free",
        updated_at: new Date().toISOString(),
      })
      .eq("id", workspaceId);
  }

  return { ok: true, userId, planCode, status: sub.status };
}

export async function applyTransaction(
  admin: SupabaseClient,
  provider: ProviderId,
  tx: NormalizedTransaction,
): Promise<ApplyResult> {
  let userId: string | null = null;
  let subscriptionId: string | null = null;
  let workspaceId: string | null = null;

  if (tx.providerSubscriptionId) {
    const { data } = await admin
      .from("billing_subscriptions")
      .select("id, user_id, workspace_id")
      .eq("provider", provider)
      .eq("provider_subscription_id", tx.providerSubscriptionId)
      .maybeSingle();

    if (data) {
      subscriptionId = data.id as string;
      userId = data.user_id as string;
      workspaceId = (data.workspace_id as string) ?? null;
    }
  }

  if (!userId && tx.providerCustomerId) {
    const { data } = await admin
      .from("billing_customers")
      .select("user_id")
      .eq("provider", provider)
      .eq("provider_customer_id", tx.providerCustomerId)
      .maybeSingle();

    userId = data?.user_id ?? null;
  }

  if (!userId) return { ok: false, reason: "TRANSACTION_WITHOUT_OWNER" };

  const { error } = await admin.from("billing_transactions").upsert({
    user_id: userId,
    workspace_id: workspaceId,
    subscription_id: subscriptionId,
    provider,
    provider_transaction_id: tx.providerTransactionId,
    invoice_url: tx.invoiceUrl,
    receipt_url: tx.receiptUrl,
    kind: "subscription",
    status: tx.status,
    currency: tx.currency,
    amount: tx.amount,
    description: tx.description,
    period_start: tx.periodStart,
    period_end: tx.periodEnd,
    occurred_at: tx.occurredAt,
  }, { onConflict: "provider,provider_transaction_id" });

  if (error) {
    console.error("No se pudo guardar el movimiento:", error.message);
    return { ok: false, reason: "TRANSACTION_WRITE_FAILED" };
  }

  return { ok: true, userId };
}
