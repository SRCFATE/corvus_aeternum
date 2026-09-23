-- Editorial choices are curated records, not owner-editable work flags.
create table public.editorial_work_selections (
  work_id uuid primary key references public.works(id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 10 and 600),
  selected_at timestamptz not null default now()
);
alter table public.editorial_work_selections enable row level security;
grant select on public.editorial_work_selections to anon, authenticated;
grant insert, update, delete on public.editorial_work_selections to authenticated;
create policy editorial_selection_read on public.editorial_work_selections
  for select to anon, authenticated using (exists (
    select 1 from public.works w where w.id = work_id
      and w.is_public and w.status = 'published'
  ));
create policy editorial_selection_admin on public.editorial_work_selections
  for all to authenticated using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- This deliberately narrow definer function exposes aggregate counts only for
-- published public works. Raw views remain inaccessible (viewer IDs and visitor
-- fingerprints never leave the database). No arbitrary work-ID lookup exists.
create function public.public_work_rankings(
  p_mode text, p_discipline text default null, p_limit integer default 40
) returns table (
  work_id uuid, recent_views bigint, previous_views bigint,
  editorial_reason text, ranked_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_mode not in ('popular', 'editorial', 'trending', 'active') or p_mode is null then
    raise exception 'Unknown ranking mode' using errcode = '22023';
  end if;
  return query
  with candidates as (
    select w.id, coalesce(w.likes_count, 0) as likes,
      coalesce(w.views_count, 0) as views,
      coalesce(w.published_at, w.created_at) as published,
      e.reason, e.selected_at,
      coalesce(v.recent, 0) as recent, coalesce(v.previous, 0) as previous
    from public.works w
    left join public.editorial_work_selections e on e.work_id = w.id
    left join lateral (
      select count(*) filter (where viewed_at >= now() - interval '7 days') as recent,
        count(*) filter (where viewed_at < now() - interval '7 days') as previous
      from public.work_views vw
      where p_mode = 'trending' and vw.work_id = w.id
        and viewed_at >= now() - interval '14 days' and viewed_at <= now()
    ) v on p_mode = 'trending'
    where w.is_public and w.status = 'published'
      and (p_discipline is null or w.discipline = p_discipline)
      and (p_mode <> 'editorial' or e.work_id is not null)
  )
  select c.id, c.recent, c.previous, c.reason,
    case when p_mode = 'editorial' then c.selected_at else c.published end
  from candidates c
  where p_mode <> 'trending' or (c.recent >= 3 and c.recent > c.previous)
  order by
    case when p_mode = 'popular' then c.likes end desc nulls last,
    case when p_mode = 'popular' then c.views end desc nulls last,
    case when p_mode = 'trending' then c.recent - c.previous end desc nulls last,
    case when p_mode = 'trending' then c.recent end desc nulls last,
    case when p_mode = 'editorial' then c.selected_at end desc nulls last,
    c.published desc nulls last, c.id
  limit greatest(1, least(coalesce(p_limit, 40), 100));
end;
$$;
revoke all on function public.public_work_rankings(text, text, integer) from public;
grant execute on function public.public_work_rankings(text, text, integer) to anon, authenticated;
