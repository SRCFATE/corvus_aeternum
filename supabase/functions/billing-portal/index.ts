import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { CORS, env, fail, json, safeReturnUrl } from "../_shared/http.ts";
import { adminClient, callerOf } from "../_shared/supabase.ts";
import { defaultProvider, ProviderError } from "../_shared/providers/index.ts";

// El portal del cliente: método de pago, facturas y datos fiscales viven en el
// proveedor, no en Corvus. Es deliberado —así ningún dato de tarjeta pasa por
// aquí— y por eso este endpoint solo abre una puerta firmada y temporal.

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail("METHOD_NOT_ALLOWED", 405);

  const caller = await callerOf(req);
  if (!caller) return fail("NOT_AUTHENTICATED", 401);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    // Sin cuerpo también vale: se usa el destino por defecto.
  }

  const admin = adminClient();
  const provider = defaultProvider();

  if (!provider.isConfigured()) {
    return fail("BILLING_PROVIDER_NOT_CONFIGURED", 503);
  }

  const workspaceId = typeof body.workspace_id === "string" && body.workspace_id
    ? body.workspace_id
    : null;

  // El portal de un workspace lo abre quien administra su facturación, que
  // puede no ser quien lo dirige.
  let ownerId = caller.id;
  if (workspaceId) {
    const { data: canManage } = await admin.rpc("atelier_has_capability", {
      p_workspace_id: workspaceId,
      p_capability: "billing.manage",
      p_profile_id: caller.id,
    });
    if (canManage !== true) return fail("NOT_AUTHORIZED", 403);

    const { data: workspace } = await admin
      .from("atelier_workspaces")
      .select("billing_owner_id")
      .eq("id", workspaceId)
      .maybeSingle();

    ownerId = workspace?.billing_owner_id ?? caller.id;
  }

  const { data: customer } = await admin
    .from("billing_customers")
    .select("provider_customer_id")
    .eq("user_id", ownerId)
    .eq("provider", provider.id)
    .maybeSingle();

  if (!customer?.provider_customer_id) {
    return fail("BILLING_NO_CUSTOMER", 404);
  }

  const base = env("BILLING_APP_URL") ?? "https://app.corvusaeternum.com";
  const returnUrl = safeReturnUrl(body.return_url, `${base}/settings/billing`);

  try {
    const session = await provider.createPortalSession(
      customer.provider_customer_id as string,
      returnUrl,
    );
    return json({ ok: true, url: session.url });
  } catch (err) {
    const reason = err instanceof ProviderError
      ? err.reasonCode
      : "BILLING_PORTAL_FAILED";
    console.error("Portal fallido:", err instanceof Error ? err.message : err);
    return fail(reason, 502);
  }
});
