import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { env } from "./http.ts";

/** Cliente con service_role: el único que puede tocar la facturación. */
export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

export interface Caller {
  id: string;
  email: string | null;
}

/**
 * Quién llama, según su propio token. No se acepta un `user_id` en el cuerpo
 * de la petición: sería decirle al servidor a nombre de quién cobrar.
 */
export async function callerOf(req: Request): Promise<Caller | null> {
  const header = req.headers.get("Authorization");
  if (!header?.toLowerCase().startsWith("bearer ")) return null;

  const anonKey = env("SUPABASE_ANON_KEY") ??
    env("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY");

  if (!anonKey) {
    console.error("Sin llave publicable para validar el token del llamante.");
    return null;
  }

  const client = createClient(Deno.env.get("SUPABASE_URL")!, anonKey, {
    global: { headers: { Authorization: header } },
    auth: { persistSession: false },
  });

  const { data, error } = await client.auth.getUser();
  if (error || !data?.user) return null;

  return { id: data.user.id, email: data.user.email ?? null };
}
