import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { CORS, fail, json } from "../_shared/http.ts";
import { adminClient, callerOf } from "../_shared/supabase.ts";
import { applySubscription } from "../_shared/apply.ts";
import {
  defaultProvider,
  NormalizedSubscription,
  ProviderError,
} from "../_shared/providers/index.ts";

// Cancelar, reactivar, cambiar de plan y resincronizar.
//
// Ninguna de estas acciones escribe el estado a mano: le piden el cambio al
// proveedor y guardan LO QUE EL PROVEEDOR DEVUELVE. Si Corvus decidiera por su
// cuenta que alguien está activo, tendríamos dos verdades y una de ellas
// cobraría distinto de lo que la app enseña.

type Action = "cancel" | "reactivate" | "change_plan" | "sync";

const ACTIONS: Action[] = ["cancel", "reactivate", "change_plan", "sync"];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail("METHOD_NOT_ALLOWED", 405);

  const caller = await callerOf(req);
  if (!caller) return fail("NOT_AUTHENTICATED", 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail("BAD_REQUEST", 400);
  }

  const action = String(body.action ?? "") as Action;
  if (!ACTIONS.includes(action)) return fail("BILLING_ACTION_UNKNOWN", 400);

  const admin = adminClient();
  const provider = defaultProvider();

  if (!provider.isConfigured()) {
    return fail("BILLING_PROVIDER_NOT_CONFIGURED", 503);
  }

  const workspaceId = typeof body.workspace_id === "string" && body.workspace_id
    ? body.workspace_id
    : null;

  if (workspaceId) {
    const { data: canManage } = await admin.rpc("atelier_has_capability", {
      p_workspace_id: workspaceId,
      p_capability: "billing.manage",
      p_profile_id: caller.id,
    });
    if (canManage !== true) return fail("NOT_AUTHORIZED", 403);
  }

  const query = admin
    .from("billing_subscriptions")
    .select("id, provider_subscription_id, status, plan_code, cancel_at_period_end")
    .eq("provider", provider.id)
    .in("status", ["trialing", "active", "past_due", "incomplete"])
    .order("created_at", { ascending: false })
    .limit(1);

  const { data: subs } = await (workspaceId
    ? query.eq("workspace_id", workspaceId)
    : query.eq("user_id", caller.id).is("workspace_id", null));

  const sub = subs?.[0];
  if (!sub?.provider_subscription_id) {
    return fail("BILLING_NO_ACTIVE_SUBSCRIPTION", 404);
  }

  try {
    let normalized: NormalizedSubscription | null = null;

    switch (action) {
      case "cancel": {
        // Siempre al final del periodo: nadie pierde días que ya pagó, y el
        // contenido no se toca ni ahora ni cuando venza.
        normalized = await provider.cancelSubscription(
          sub.provider_subscription_id as string,
          true,
        );
        break;
      }

      case "reactivate": {
        normalized = await provider.reactivateSubscription(
          sub.provider_subscription_id as string,
        );
        break;
      }

      case "change_plan": {
        const priceId = String(body.price_id ?? "").trim();
        if (!priceId) return fail("BILLING_PRICE_REQUIRED", 400);

        const { data: price } = await admin
          .from("billing_prices")
          .select("provider, provider_price_id, is_active, billing_products(is_active)")
          .eq("id", priceId)
          .maybeSingle();

        // deno-lint-ignore no-explicit-any
        if (!price?.is_active || !(price as any).billing_products?.is_active) {
          return fail("BILLING_PRICE_NOT_AVAILABLE", 404);
        }
        if (price.provider !== provider.id) {
          return fail("BILLING_PROVIDER_MISMATCH", 409);
        }
        if (!price.provider_price_id) {
          return fail("BILLING_PRICE_NOT_CONFIGURED", 503);
        }

        normalized = await provider.changePlan(
          sub.provider_subscription_id as string,
          price.provider_price_id as string,
        );
        break;
      }

      case "sync": {
        normalized = await provider.fetchSubscription(
          sub.provider_subscription_id as string,
        );
        break;
      }
    }

    if (!normalized) return fail("BILLING_SUBSCRIPTION_NOT_FOUND", 404);

    // La metadata puede venir vacía si la suscripción se creó fuera del
    // checkout; se completa con lo que ya sabemos para no perder al titular.
    normalized.metadata = {
      corvus_user_id: caller.id,
      corvus_workspace_id: workspaceId ?? "",
      ...normalized.metadata,
    };

    const result = await applySubscription(admin, provider.id, normalized);
    if (!result.ok) return fail(result.reason ?? "BILLING_SYNC_FAILED", 500);

    if (action !== "sync") {
      await admin.from("billing_analytics_events").insert({
        profile_id: caller.id,
        workspace_id: workspaceId,
        event: action === "cancel"
          ? "subscription_canceled"
          : action === "reactivate"
          ? "subscription_reactivated"
          : "upgrade_completed",
        plan_code: result.planCode,
        properties: { from_plan: sub.plan_code, to_plan: result.planCode },
      });
    }

    return json({
      ok: true,
      status: normalized.status,
      plan_code: result.planCode,
      cancel_at_period_end: normalized.cancelAtPeriodEnd,
      current_period_end: normalized.currentPeriodEnd,
    });
  } catch (err) {
    const reason = err instanceof ProviderError
      ? err.reasonCode
      : "BILLING_ACTION_FAILED";
    console.error("Acción de facturación fallida:", err instanceof Error ? err.message : err);
    return fail(reason, 502);
  }
});
