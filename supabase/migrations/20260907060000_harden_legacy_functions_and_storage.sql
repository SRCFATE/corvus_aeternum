-- Endurecimiento del tramo antiguo de Corvus.
--
-- Las migraciones de septiembre de 2026 (Atelier, facturación) ya nacen con
-- `search_path` fijado y sin EXECUTE para el cliente. Las anteriores —las que
-- solo vivían en el proyecto remoto— no, y el linter las señala una por una.
-- Esta migración las pone al mismo nivel y, de paso, cierra dos puertas de
-- Storage que estaban abiertas de verdad.

-- ─────────────────────────────────────────────────────────────
-- 1. Las funciones de trigger no son endpoints
-- ─────────────────────────────────────────────────────────────
-- Las funciones que devuelven `trigger` quedan publicadas en /rest/v1/rpc/.
-- Llamarlas fuera de un trigger falla, pero no hay ninguna razón para que
-- estén ahí: una firma de menos es una firma menos que auditar.
--
-- El permiso hay que quitárselo a **PUBLIC**, no a `anon` y `authenticated`.
-- Esto no viene del `alter default privileges` de Supabase sino de PostgreSQL
-- mismo, que concede EXECUTE a PUBLIC en toda función nueva: la ACL se lee
-- `{=X/postgres,…}`, y ese `=X` inicial, sin rol delante, es PUBLIC.
-- Revocarlo de `anon` fue un no-op —nunca lo tuvo a su nombre— y el linter
-- siguió marcando las diecinueve.
--
-- Revocar de PUBLIC no impide que el trigger dispare: PostgreSQL comprueba
-- EXECUTE al crear el trigger, no al ejecutarlo. Comprobado contra este mismo
-- servidor con una tabla de prueba y `set local role authenticated`, dentro de
-- una transacción revertida.
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prorettype = 'pg_catalog.trigger'::regtype
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  loop
    execute format(
      'revoke execute on function %s from public, anon, authenticated', fn.sig
    );
  end loop;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- 2. search_path fijado en las funciones que lo tenían suelto
-- ─────────────────────────────────────────────────────────────
-- Hoy no es explotable: ni `anon` ni `authenticated` tienen CREATE en ningún
-- esquema, así que nadie puede plantar una tabla que secuestre una referencia
-- sin cualificar. Es defensa en profundidad: el día que una migración conceda
-- CREATE por descuido, estas funciones —varias SECURITY DEFINER— dejarían de
-- ser seguras sin que nadie las tocara.
alter function public.set_updated_at()                set search_path = public, pg_temp;
alter function public.handle_new_user()               set search_path = public, pg_temp;
alter function public.sync_artist_followers()         set search_path = public, pg_temp;
alter function public.update_comments_count()         set search_path = public, pg_temp;
alter function public.update_saves_count()            set search_path = public, pg_temp;
alter function public.notify_on_like()                set search_path = public, pg_temp;
alter function public.notify_on_follow()              set search_path = public, pg_temp;
alter function public.notify_on_comment()             set search_path = public, pg_temp;
alter function public.notify_verification_result()    set search_path = public, pg_temp;
alter function public.create_feed_event_on_work()     set search_path = public, pg_temp;
alter function public.handle_verification_approval()  set search_path = public, pg_temp;

-- Esta entra en un índice de expresión y su cuerpo ya cualifica todo
-- (`public.unaccent('public.unaccent', $1)`), así que fijar el camino no
-- cambia su resultado y el índice sigue siendo válido.
alter function public.immutable_unaccent(text)        set search_path = public, pg_temp;

-- ─────────────────────────────────────────────────────────────
-- 3. Tablas de solo-lectura para el servidor: quitar los grants sobrantes
-- ─────────────────────────────────────────────────────────────
-- Las tres tienen RLS activada y cero políticas, o sea deny-all a propósito.
-- La RLS ya las protege; el grant de escritura que dejó el default de Supabase
-- es un cinturón suelto. Si mañana alguien añade una política de SELECT para
-- depurar, el INSERT/UPDATE/DELETE quedaría vivo detrás.
revoke insert, update, delete, truncate on public.conspiracy_audit_log     from anon, authenticated;
revoke insert, update, delete, truncate on public.conspiracy_domain_events from anon, authenticated;
revoke insert, update, delete, truncate on public.work_views               from anon, authenticated;

-- ─────────────────────────────────────────────────────────────
-- 4. Storage: el avatar de alguien no se toca
-- ─────────────────────────────────────────────────────────────
-- Aquí sí había una puerta abierta. Las políticas de Postgres se suman con OR,
-- y sobre `storage.objects` convivían dos familias:
--
--   estricta -> "avatars insert/update own folder": foldername(name)[1] = auth.uid()
--   laxa     -> "Auth sube/actualiza avatar":       bucket_id = 'avatars' and auth.role() = 'authenticated'
--
-- La laxa gana siempre. Cualquiera con sesión podía sobrescribir el avatar de
-- cualquier otro artista —la ruta es previsible, `{uid}/avatar.png`— o subir
-- archivos arbitrarios a un bucket público. Lo mismo en `works`, y en
-- `covers`/`auctions`/`collections`, donde además no había límite de carpeta.
drop policy if exists "Auth sube avatar"      on storage.objects;
drop policy if exists "Auth actualiza avatar" on storage.objects;
drop policy if exists "Auth sube work"        on storage.objects;
drop policy if exists "Auth sube cover"       on storage.objects;

-- Lo que sube la app va a `{uid}/…` en todos los buckets públicos, así que la
-- carpeta es la prueba de propiedad. Una sola política por verbo, sin variante
-- laxa que la anule.
--
-- La cláusula de `images/` es un puente, y tiene fecha de caducidad. La versión
-- de la app que hay hoy en producción sube las obras a
-- `images/{uid}_{momento}.ext`, no a `{uid}/…`. Sin este puente, aplicar la
-- migración antes de desplegar el cliente nuevo dejaría rota la publicación de
-- obra hasta que el despliegue llegara —y el orden de esas dos cosas no
-- debería importar—. Sigue siendo una prueba de propiedad: esa ruta lleva el
-- identificador de quien sube dentro del nombre, así que nadie puede escribir
-- en el hueco de otro. Se retira cuando la versión nueva lleve un tiempo
-- desplegada.
drop policy if exists "corvus_public_buckets_insert" on storage.objects;
create policy "corvus_public_buckets_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'banners', 'works', 'covers', 'auctions', 'collections')
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (
        bucket_id = 'works'
        and starts_with(name, 'images/' || (select auth.uid())::text || '_')
      )
    )
  );

drop policy if exists "corvus_public_buckets_update" on storage.objects;
create policy "corvus_public_buckets_update"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('avatars', 'banners', 'works', 'covers', 'auctions', 'collections')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('avatars', 'banners', 'works', 'covers', 'auctions', 'collections')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "corvus_public_buckets_delete" on storage.objects;
create policy "corvus_public_buckets_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('avatars', 'banners', 'works', 'covers', 'auctions', 'collections')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- La lectura pública se mantiene: son buckets públicos y las obras se
-- comparten por enlace. Se unifican las políticas duplicadas en una.
drop policy if exists "Público lee avatars" on storage.objects;
drop policy if exists "Público lee covers"  on storage.objects;
drop policy if exists "Público lee works"   on storage.objects;
drop policy if exists "Works public read"   on storage.objects;
drop policy if exists "avatars read"        on storage.objects;

drop policy if exists "corvus_public_buckets_read" on storage.objects;
create policy "corvus_public_buckets_read"
  on storage.objects for select
  using (
    bucket_id in ('avatars', 'banners', 'works', 'covers', 'auctions', 'collections')
  );

-- Las políticas antiguas de `works` por carpeta quedan subsumidas.
drop policy if exists "Users upload own works" on storage.objects;
drop policy if exists "Users update own works" on storage.objects;
drop policy if exists "Users delete own works" on storage.objects;

-- El bucket que la app usaba sin que existiera. `uploadBanner()` fallaba
-- siempre: guardar el perfil con una portada nueva reventaba en silencio.
insert into storage.buckets (id, name, public)
values ('banners', 'banners', true)
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────────
-- 5. Ningún bucket público acepta HTML ni SVG
-- ─────────────────────────────────────────────────────────────
-- `image/*` incluye `image/svg+xml`, y un SVG es un documento con scripts. Un
-- .svg o un .html servido desde el dominio de Storage es XSS alojado y firmado
-- por nosotros. La lista se vuelve explícita, sin comodines.
update storage.buckets
set allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'image/heic', 'image/heif', 'image/bmp'
    ],
    file_size_limit = coalesce(file_size_limit, 15728640)
where id in ('avatars', 'banners', 'works', 'covers', 'auctions', 'collections');
