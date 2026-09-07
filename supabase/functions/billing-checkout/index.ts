import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { CORS, env, fail, json, safeReturnUrl } from "../_shared/http.ts";
import { adminClient, callerOf } from "../_shared/supabase.ts";
import { defaultProvider, ProviderError } from "../_shared/providers/index.ts";

// Abrir el cobro de un plan.
//
// El cliente manda un `price_id` NUESTRO, nunca uno del proveedor: así el
// importe, la moneda y el plan salen de la base de datos y no de la petición.
// Alguien que manipule el cuerpo solo consigue elegir otro precio del catálogo
// público, que es exactamente lo que la pantalla de Planes ya le ofrece.

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

  const priceId = String(body.price_id ?? "").trim();
  if (!priceId) return fail("BILLING_PRICE_REQUIRED", 400);

  const workspaceId = typeof body.workspace_id === "string" && body.workspace_id
    ? body.workspace_id
    : null;

  const admin = adminClient();

  // La bandera decide si el cobro está abierto para esta cuenta. Sin ella,
  // Atelier funciona igual: solo no se puede pagar todavía.
  const { data: flagOn } = await admin.rpc("is_feature_enabled", {
    p_key: "billing",
    p_profile_id: caller.id,
  });
  if (flagOn !== true) return fail("BILLING_NOT_AVAILABLE", 403);

  const { data: price } = await admin
    .from("billing_prices")
    .select(
      "id, provider, provider_price_id, unit_amount, currency, trial_days, is_active, " +
        "billing_products(id, is_active, plan_code, plans(code, is_active, scope))",
    )
    .eq("id", priceId)
    .maybeSingle();

  // deno-lint-ignore no-explicit-any
  const product = (price as any)?.billing_products;
  const plan = product?.plans;

  if (!price?.is_active || !product?.is_active || !plan?.is_active) {
    return fail("BILLING_PRICE_NOT_AVAILABLE", 404);
  }

  const provider = defaultProvider();
  if (price.provider !== provider.id) {
    return fail("BILLING_PROVIDER_MISMATCH", 409);
  }
  if (!provider.isConfigured()) {
    return fail("BILLING_PROVIDER_NOT_CONFIGURED", 503);
  }
  if (!price.provider_price_id) {
    // El catálogo existe pero nadie ha creado aún el precio en el proveedor.
    return fail("BILLING_PRICE_NOT_CONFIGURED", 503);
  }

  // Un plan de workspace se cobra al workspace, y solo quien lo administra.
  if (plan.scope === "workspace") {
    if (!workspaceId) return fail("BILLING_WORKSPACE_REQUIRED", 400);

    const { data: canManage } = await admin.rpc("atelier_has_capability", {
      p_workspace_id: workspaceId,
      p_capability: "billing.manage",
      p_profile_id: caller.id,
    });
    if (canManage !== true) return fail("NOT_AUTHORIZED", 403);
  } else if (workspaceId) {
    return fail("BILLING_PLAN_IS_PERSONAL", 400);
  }

  const base = env("BILLING_APP_URL") ?? "https://app.corvusaeternum.com";
  const successUrl = safeReturnUrl(
    body.success_url,
    `${base}/settings/billing?checkout=ok`,
  );
  const cancelUrl = safeReturnUrl(body.cancel_url, `${base}/plans`);

  const { data: customer } = await admin
    .from("billing_customers")
    .select("provider_customer_id")
    .eq("user_id", caller.id)
    .eq("provider", provider.id)
    .maybeSingle();

  try {
    const customerId = await provider.ensureCustomer(
      caller.id,
      caller.email,
      customer?.provider_customer_id ?? null,
    );

    if (!customer?.provider_customer_id) {
      await admin.from("billing_customers").upsert({
        user_id: caller.id,
        provider: provider.id,
        provider_customer_id: customerId,
        email: caller.email,
      }, { onConflict: "user_id,provider" });
    }

    const session = await provider.createCheckout({
      userId: caller.id,
      email: caller.email,
      customerId,
      providerPriceId: price.provider_price_id as string,
      planCode: plan.code as string,
      priceId: price.id as string,
      workspaceId,
      successUrl,
      cancelUrl,
      trialDays: Number(price.trial_days ?? 0),
      couponCode: typeof body.coupon === "string" ? body.coupon : null,
    });

    await admin.from("billing_analytics_events").insert({
      profile_id: caller.id,
      workspace_id: workspaceId,
      event: "checkout_started",
      plan_code: plan.code,
      properties: { price_id: price.id, provider: provider.id },
    });

    return json({ ok: true, url: session.url, session_id: session.providerSessionId });
  } catch (err) {
    const reason = err instanceof ProviderError
      ? err.reasonCode
      : "BILLING_CHECKOUT_FAILED";
    console.error("Checkout fallido:", err instanceof Error ? err.message : err);
    return fail(reason, 502);
  }
});
