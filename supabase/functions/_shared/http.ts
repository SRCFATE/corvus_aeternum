// Piezas comunes a las funciones de facturación de Corvus.
//
// El contrato de respuesta es el mismo que el del resto del archivo:
// `{ ok: true, ... }` o `{ ok: false, reason_code }`, para que en Dart
// `unwrapRpc()` trate igual una RPC de Postgres y una Edge Function.

export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

export const fail = (reasonCode: string, status = 400, extra?: object) =>
  json({ ok: false, reason_code: reasonCode, ...extra }, status);

export const env = (key: string): string | undefined =>
  Deno.env.get(key)?.trim() || undefined;

/** Solo se aceptan destinos de vuelta dentro de Corvus. */
export function safeReturnUrl(
  candidate: unknown,
  fallback: string,
): string {
  if (typeof candidate !== "string" || candidate.length === 0) return fallback;

  let url: URL;
  try {
    url = new URL(candidate);
  } catch {
    return fallback;
  }

  if (url.protocol !== "https:" && url.protocol !== "http:") return fallback;

  const allowed = (env("BILLING_ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((o) => o.trim())
    .filter(Boolean);

  if (allowed.length === 0) return fallback;

  return allowed.includes(url.origin) ? candidate : fallback;
}
