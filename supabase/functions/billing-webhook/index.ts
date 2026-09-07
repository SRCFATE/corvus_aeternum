import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { fail, json } from "../_shared/http.ts";
import { adminClient } from "../_shared/supabase.ts";
import { applySubscription, applyTransaction } from "../_shared/apply.ts";
import { providerFor, defaultProvider } from "../_shared/providers/index.ts";

// El aviso del proveedor.
//
// Idempotencia, por capas:
//   1. la firma se verifica antes de leer nada (sin firma no hay evento);
//   2. `billing_events` tiene único (provider, provider_event_id): el segundo
//      intento del mismo aviso choca contra el índice y se reconoce, no se
//      procesa dos veces;
//   3. los escritos son upsert por identificador del proveedor, así que
//      incluso si algo llegara duplicado, el resultado sería el mismo.
//
// Y una regla que no se negocia: aquí NUNCA se borra contenido. Una baja
// cambia el estado de la suscripción y nada más. Los proyectos, los archivos
// y los comentarios de quien deja de pagar siguen exactamente donde estaban.

const SIGNATURE_HEADERS = ["stripe-signature", "x-signature"];

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return fail("METHOD_NOT_ALLOWED", 405);

  const url = new URL(req.url);
  const provider = providerFor(url.searchParams.get("provider") ?? "") ??
    defaultProvider();

  const rawBody = await req.text();
  const signature = SIGNATURE_HEADERS
    .map((h) => req.headers.get(h))
    .find((v) => v != null) ?? null;

  const event = await provider.parseWebhook(rawBody, signature);
  if (!event) {
    // No se distingue entre firma ausente e inválida: quien sondea no aprende.
    return fail("WEBHOOK_SIGNATURE_INVALID", 401);
  }

  const admin = adminClient();

  const { error: insertError } = await admin.from("billing_events").insert({
    provider: provider.id,
    provider_event_id: event.id,
    event_type: event.type,
    payload: event.payload,
    status: "received",
  });

  if (insertError) {
    // 23505 = ya lo procesamos. Se responde 200 para que el proveedor deje de
    // reintentar: repetir no cambiaría nada y sí llenaría la cola.
    if (insertError.code === "23505") {
      return json({ ok: true, duplicate: true });
    }
    console.error("No se pudo registrar el aviso:", insertError.message);
    return fail("WEBHOOK_STORE_FAILED", 500);
  }

  const notes: string[] = [];
  let failed = false;

  try {
    if (event.subscription) {
      const result = await applySubscription(admin, provider.id, event.subscription);
      notes.push(`subscription:${result.ok ? result.status : result.reason}`);
      if (!result.ok) failed = true;
    }

    if (event.transaction) {
      const result = await applyTransaction(admin, provider.id, event.transaction);
      notes.push(`transaction:${result.ok ? "ok" : result.reason}`);
      if (!result.ok) failed = true;
    }

    if (notes.length === 0) notes.push("ignored");
  } catch (err) {
    failed = true;
    notes.push(err instanceof Error ? err.message : String(err));
    console.error("Aviso no procesado:", err);
  }

  await admin
    .from("billing_events")
    .update({
      status: failed ? "failed" : notes[0] === "ignored" ? "ignored" : "processed",
      error: failed ? notes.join(" | ") : null,
      processed_at: new Date().toISOString(),
    })
    .eq("provider", provider.id)
    .eq("provider_event_id", event.id);

  // Un fallo nuestro sí merece reintento del proveedor: 500.
  if (failed) return fail("WEBHOOK_PROCESSING_FAILED", 500, { notes });

  return json({ ok: true, event: event.type, notes });
});
