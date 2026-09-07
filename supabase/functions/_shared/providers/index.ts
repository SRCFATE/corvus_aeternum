import { BillingProvider, ProviderId } from "./types.ts";
import { StripeBillingProvider } from "./stripe.ts";
import { MercadoPagoBillingProvider } from "./mercadopago.ts";

const registry: Record<ProviderId, BillingProvider> = {
  stripe: new StripeBillingProvider(),
  mercadopago: new MercadoPagoBillingProvider(),
};

export function providerFor(id: string): BillingProvider | null {
  return registry[id as ProviderId] ?? null;
}

/**
 * El proveedor por defecto sale de la variable de entorno, no del código: el
 * día que Corvus cobre en México con otra pasarela, se cambia un secreto.
 */
export function defaultProvider(): BillingProvider {
  const id = (Deno.env.get("BILLING_PROVIDER")?.trim() || "stripe") as ProviderId;
  return registry[id] ?? registry.stripe;
}

export * from "./types.ts";
