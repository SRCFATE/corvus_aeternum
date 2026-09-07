import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

// Envía el código de recuperación de 8 caracteres.
//
// El correo de Supabase manda un enlace al Site URL (localhost), inútil en
// escritorio. Esta función pide el código a la base con service_role —único
// contexto que puede verlo en claro— y lo pone en un correo propio.
//
// Vías de envío, en orden:
//   1. Resend        → RESEND_API_KEY
//   2. SMTP genérico → SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
//
// El remitente sale de RECOVERY_FROM_EMAIL si está definido; si no, se
// descubre solo consultando los dominios verificados de la cuenta Resend.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

const env = (k: string) => Deno.env.get(k)?.trim() || undefined;

let cachedPublicKeys: Set<string> | undefined;

function keysFromJsonBag(raw?: string): string[] {
  if (!raw) return [];

  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      return parsed.filter(
        (value): value is string => typeof value === "string",
      );
    }
    if (parsed && typeof parsed === "object") {
      return Object.values(parsed).filter(
        (value): value is string => typeof value === "string",
      );
    }
  } catch {
    return [raw];
  }

  return [];
}

function configuredPublicKeys(): Set<string> {
  if (cachedPublicKeys) return cachedPublicKeys;

  const keys = new Set<string>();
  for (const key of keysFromJsonBag(env("SUPABASE_PUBLISHABLE_KEYS"))) {
    keys.add(key);
  }

  const legacyAnon = env("SUPABASE_ANON_KEY");
  if (legacyAnon) keys.add(legacyAnon);

  cachedPublicKeys = keys;
  return keys;
}

function bearerToken(req: Request): string | undefined {
  const header = req.headers.get("authorization")?.trim();
  if (!header?.toLowerCase().startsWith("bearer ")) return undefined;
  return header.slice("bearer ".length).trim();
}

function callerHasProjectKey(req: Request): boolean {
  const allowed = configuredPublicKeys();
  if (allowed.size === 0) {
    console.error("No hay llaves publicables disponibles para validar cliente.");
    return false;
  }

  const candidates = [req.headers.get("apikey")?.trim(), bearerToken(req)];
  return candidates.some((key) => key != null && allowed.has(key));
}

class SendError extends Error {
  constructor(readonly reasonCode: string, message: string) {
    super(message);
  }
}

function emailHtml(code: string, minutes: number): string {
  return `<!doctype html>
<html lang="es">
  <body style="margin:0;padding:32px 16px;background:#09090C;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      <tr><td align="center">
        <table role="presentation" width="100%" style="max-width:480px;background:#100C14;border:1px solid rgba(255,255,255,0.08);border-radius:18px;" cellpadding="0" cellspacing="0">
          <tr><td style="padding:32px 32px 8px;">
            <div style="color:#CC3333;font-size:11px;font-weight:900;letter-spacing:1.8px;">CORVUS AETERNUM</div>
            <h1 style="margin:14px 0 0;color:#F0EEE6;font-size:22px;font-weight:800;letter-spacing:-0.5px;">Recupera tu acceso</h1>
            <p style="margin:12px 0 0;color:rgba(255,255,255,0.55);font-size:14px;line-height:1.6;">
              Escribe este código en la app para elegir una contraseña nueva.
            </p>
          </td></tr>
          <tr><td style="padding:24px 32px;">
            <div style="background:rgba(204,51,51,0.08);border:1px solid rgba(204,51,51,0.30);border-radius:14px;padding:22px;text-align:center;">
              <div style="color:#F0EEE6;font-size:32px;font-weight:800;letter-spacing:10px;font-family:'SFMono-Regular',Consolas,monospace;">${code}</div>
            </div>
            <p style="margin:16px 0 0;color:rgba(255,255,255,0.38);font-size:12px;line-height:1.6;text-align:center;">
              Caduca en ${minutes} minutos. Si no pediste esto, ignora el mensaje:<br/>tu contraseña sigue intacta.
            </p>
          </td></tr>
          <tr><td style="padding:0 32px 30px;">
            <div style="border-top:1px solid rgba(255,255,255,0.07);padding-top:16px;color:rgba(255,255,255,0.28);font-size:11px;">
              El archivo no olvida a los suyos.
            </div>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}

function mailerAvailable(): boolean {
  if (env("RESEND_API_KEY")) return true;
  return Boolean(env("SMTP_HOST") && env("SMTP_USER") && env("SMTP_PASS"));
}

// Se resuelve una vez por instancia: la lista de dominios cambia muy poco.
let cachedFrom: string | undefined;

/**
 * Remitente a usar. RECOVERY_FROM_EMAIL manda; si no está, se pregunta a
 * Resend por un dominio verificado, para no obligar a definir el secreto
 * después de verificar el dominio.
 */
async function resolveFrom(resendKey?: string): Promise<string> {
  const explicit = env("RECOVERY_FROM_EMAIL");
  if (explicit) return explicit;
  if (cachedFrom) return cachedFrom;

  if (resendKey) {
    try {
      const res = await fetch("https://api.resend.com/domains", {
        headers: { Authorization: `Bearer ${resendKey}` },
      });
      if (res.ok) {
        const body = await res.json();
        const domains: Array<{ name?: string; status?: string }> =
          body?.data ?? [];
        const verified = domains.find((d) => d.status === "verified")?.name;
        if (verified) {
          cachedFrom = `Corvus Aeternum <no-responder@${verified}>`;
          console.log("Remitente descubierto:", cachedFrom);
          return cachedFrom;
        }
      } else {
        console.error("No se pudo listar dominios:", res.status);
      }
    } catch (err) {
      console.error("Fallo consultando dominios:", err);
    }
  }

  return "Corvus Aeternum <onboarding@resend.dev>";
}

async function sendEmail(to: string, subject: string, html: string) {
  const resendKey = env("RESEND_API_KEY");
  const from = await resolveFrom(resendKey);

  if (resendKey) {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from, to: [to], subject, html }),
    });
    if (res.ok) return;

    const detail = await res.text();
    // Con el remitente de pruebas Resend solo entrega al dueño de la cuenta:
    // la salida es verificar un dominio, no reintentar.
    if (res.status === 403 && detail.includes("testing emails")) {
      throw new SendError(
        "EMAIL_DOMAIN_NOT_VERIFIED",
        `Resend 403 usando from="${from}": ${detail}`,
      );
    }
    throw new SendError("EMAIL_SEND_FAILED", `Resend ${res.status}: ${detail}`);
  }

  const client = new SMTPClient({
    connection: {
      hostname: env("SMTP_HOST")!,
      port: Number(env("SMTP_PORT") ?? "465"),
      tls: (env("SMTP_PORT") ?? "465") === "465",
      auth: { username: env("SMTP_USER")!, password: env("SMTP_PASS")! },
    },
  });
  try {
    await client.send({ from, to, subject, html, content: "auto" });
  } finally {
    await client.close();
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") {
    return json({ ok: false, reason_code: "METHOD_NOT_ALLOWED" }, 405);
  }

  if (!callerHasProjectKey(req)) {
    return json(
      { ok: false, reason_code: "RECOVERY_CLIENT_UNAUTHORIZED" },
      401,
    );
  }

  // Se comprueba ANTES de emitir: si no se puede enviar, no tiene sentido
  // quemar un código ni un intento del límite por hora del artista.
  if (!mailerAvailable()) {
    console.error(
      "Sin vía de envío. Define RESEND_API_KEY, o SMTP_HOST/SMTP_USER/SMTP_PASS.",
    );
    return json({ ok: false, reason_code: "EMAIL_NOT_CONFIGURED" }, 503);
  }

  let email = "";
  try {
    const body = await req.json();
    email = String(body?.email ?? "").trim().toLowerCase();
  } catch {
    return json({ ok: false, reason_code: "BAD_REQUEST" }, 400);
  }

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json({ ok: false, reason_code: "EMAIL_INVALID" }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data, error } = await admin.rpc("issue_password_recovery_code", {
    p_email: email,
  });

  if (error) {
    console.error("issue_password_recovery_code:", error.message);
    return json({ ok: false, reason_code: "RECOVERY_ISSUE_FAILED" }, 500);
  }

  if (data?.ok === false) {
    return json(
      { ok: false, reason_code: data.reason_code ?? "RECOVERY_ISSUE_FAILED" },
      429,
    );
  }

  // La cuenta no existe: se responde como si todo hubiera salido bien.
  if (data?.send !== true) return json({ ok: true });

  try {
    await sendEmail(
      email,
      `${data.code} — tu código para recuperar el acceso`,
      emailHtml(data.code, data.expires_in_minutes ?? 15),
    );
  } catch (err) {
    const reason =
      err instanceof SendError ? err.reasonCode : "EMAIL_SEND_FAILED";
    console.error("Envío fallido:", err instanceof Error ? err.message : err);
    return json({ ok: false, reason_code: reason }, 502);
  }

  return json({ ok: true });
});
