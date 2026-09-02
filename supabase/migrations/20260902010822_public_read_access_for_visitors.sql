-- Corvus abre el descubrimiento a visitantes sin sesión. La participación
-- (like, guardar, comentar, seguir, publicar) sigue exigiendo auth.uid(),
-- que ya imponen las políticas de escritura.

-- B1 · Una obra solo es pública si realmente está publicada.
-- Hasta ahora el candado era `is_public`, y la invariante
-- `is_public = (status = 'published')` la mantenía solo el cliente.
alter policy "Obras públicas"
on public.works
using (
  (is_public and status = 'published')
  or auth.uid() = profile_id
);

-- B2 · Los perfiles suspendidos dejan de ser visibles, pero su propietario
-- sigue leyendo el suyo.
alter policy "profiles_select_public"
on public.profiles
using (
  not is_banned
  or auth.uid() = id
);

-- B3a · El certificado de una obra pública se consulta sin sesión. La función
-- solo delega en verify_aeternum_certificate, que ya era ejecutable por anon,
-- así que no expone nada nuevo.
grant execute
on function public.get_work_aeternum_certificate(uuid)
to anon;

-- B3b · Arena abierta a visitantes. Con auth.uid() nulo, la condición ya
-- existente se reduce sola a `visibility = 'public'`.
alter policy "arena challenges are readable"
on public.arena_challenges
to anon, authenticated;

alter policy "arena entries are readable"
on public.arena_entries
to anon, authenticated;
