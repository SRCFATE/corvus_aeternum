-- Las vistas dejan de escribirse por INSERT directo. La única vía es este RPC,
-- que valida que la obra sea pública y deduplica por espectador, para que
-- Tendencias no se pueda inflar repitiendo la llamada contra la API.

create index if not exists work_views_dedup_idx
  on public.work_views (work_id, viewed_at desc);

create or replace function public.record_work_view(
  p_work_id uuid,
  p_visitor_token text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viewer uuid := auth.uid();
  v_token text := nullif(left(coalesce(p_visitor_token, ''), 64), '');
  v_ventana constant interval := interval '6 hours';
begin
  -- Solo se contabiliza lo que el público puede ver. Un borrador no suma.
  if not exists (
    select 1
    from public.works w
    where w.id = p_work_id
      and w.is_public
      and w.status = 'published'
  ) then
    return;
  end if;

  -- El espectador es la cuenta si la hay, y si no el testigo del navegador.
  -- Sin ninguno de los dos no habría con qué deduplicar, así que no se anota.
  if v_viewer is null and v_token is null then
    return;
  end if;

  if exists (
    select 1
    from public.work_views v
    where v.work_id = p_work_id
      and v.viewed_at > now() - v_ventana
      and (
        (v_viewer is not null and v.viewer_id = v_viewer)
        or (v_viewer is null and v.viewer_id is null and v.fingerprint = v_token)
      )
  ) then
    return;
  end if;

  insert into public.work_views (work_id, viewer_id, fingerprint)
  values (
    p_work_id,
    v_viewer,
    case when v_viewer is null then v_token end
  );
end;
$$;

revoke all on function public.record_work_view(uuid, text) from public;
grant execute on function public.record_work_view(uuid, text) to anon, authenticated;

-- Se retira la escritura directa: el RPC es SECURITY DEFINER y no la necesita.
drop policy if exists "Insertar vista" on public.work_views;
