-- Corvus Aeternum / Conspiracy algorithms v5
-- Server-authoritative progress, invitations, endorsements and automation.

create schema if not exists private;
revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

create table if not exists private.conspiracy_curators (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

revoke all on table private.conspiracy_curators from public;
revoke all on table private.conspiracy_curators from anon;
revoke all on table private.conspiracy_curators from authenticated;

create index if not exists conspiracy_curators_granted_by_idx
  on private.conspiracy_curators(granted_by)
  where granted_by is not null;

create table if not exists public.conspiracy_rules (
  conspiracy_id uuid primary key references public.conspirations(id) on delete cascade,
  algorithm_key text not null unique,
  metric_label text not null,
  target_value numeric not null check (target_value > 0),
  unlock_mode text not null check (
    unlock_mode in ('root', 'manual', 'automatic', 'invitation', 'curated')
  ),
  effect_key text not null,
  config jsonb not null default '{}'::jsonb,
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.conspiracy_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  conspiracy_id uuid not null references public.conspirations(id) on delete cascade,
  metric_value numeric not null default 0,
  target_value numeric not null default 1,
  level integer not null default 0 check (level >= 0),
  state text not null default 'tracking' check (
    state in (
      'available', 'active', 'awakened', 'tracking', 'eligible',
      'candidate', 'unlocked', 'hidden', 'veiled'
    )
  ),
  details jsonb not null default '{}'::jsonb,
  evaluated_at timestamptz not null default now(),
  primary key (user_id, conspiracy_id)
);

create table if not exists public.conspiracy_daily_activity (
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_date date not null,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  source text not null default 'app',
  primary key (user_id, activity_date)
);

create table if not exists public.conspiracy_invitations (
  id uuid primary key default gen_random_uuid(),
  conspiracy_id uuid not null references public.conspirations(id) on delete cascade,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  evidence_work_id uuid references public.works(id) on delete set null,
  note text not null default '' check (char_length(note) <= 1000),
  status text not null default 'pending' check (
    status in ('pending', 'accepted', 'declined', 'expired', 'revoked')
  ),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  responded_at timestamptz,
  check (inviter_id <> invitee_id),
  check (expires_at > created_at)
);

create table if not exists public.conspiracy_endorsements (
  id uuid primary key default gen_random_uuid(),
  conspiracy_id uuid not null references public.conspirations(id) on delete cascade,
  endorser_id uuid not null references auth.users(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  evidence_work_id uuid references public.works(id) on delete set null,
  note text not null default '' check (char_length(note) between 1 and 1200),
  created_at timestamptz not null default now(),
  check (endorser_id <> candidate_id),
  unique (conspiracy_id, endorser_id, candidate_id)
);

create index if not exists conspiracy_progress_state_idx
  on public.conspiracy_progress(user_id, state, evaluated_at desc);
create index if not exists conspiracy_progress_house_idx
  on public.conspiracy_progress(conspiracy_id);
create index if not exists conspiracy_activity_recent_idx
  on public.conspiracy_daily_activity(user_id, activity_date desc);
create index if not exists conspiracy_invites_invitee_idx
  on public.conspiracy_invitations(invitee_id, status, created_at desc);
create index if not exists conspiracy_invites_inviter_year_idx
  on public.conspiracy_invitations(inviter_id, created_at desc);
create index if not exists conspiracy_invites_evidence_idx
  on public.conspiracy_invitations(evidence_work_id)
  where evidence_work_id is not null;
create unique index if not exists conspiracy_invites_one_pending_idx
  on public.conspiracy_invitations(conspiracy_id, inviter_id, invitee_id)
  where status = 'pending';
create index if not exists conspiracy_endorsements_candidate_idx
  on public.conspiracy_endorsements(conspiracy_id, candidate_id, created_at desc);
create index if not exists conspiracy_endorsements_candidate_fk_idx
  on public.conspiracy_endorsements(candidate_id);
create index if not exists conspiracy_endorsements_endorser_idx
  on public.conspiracy_endorsements(endorser_id);
create index if not exists conspiracy_endorsements_evidence_idx
  on public.conspiracy_endorsements(evidence_work_id)
  where evidence_work_id is not null;
create unique index if not exists conspiracy_return_event_work_idx
  on public.conspiracy_domain_events(user_id, event_key, ((payload ->> 'work_id')))
  where event_key = 'artist_return_detected';

alter table public.conspiracy_rules enable row level security;
alter table public.conspiracy_progress enable row level security;
alter table public.conspiracy_daily_activity enable row level security;
alter table public.conspiracy_invitations enable row level security;
alter table public.conspiracy_endorsements enable row level security;

grant select on table public.conspiracy_rules to authenticated;
grant select on table public.conspiracy_progress to authenticated;
grant select on table public.conspiracy_daily_activity to authenticated;
grant select on table public.conspiracy_invitations to authenticated;
grant select on table public.conspiracy_endorsements to authenticated;

drop policy if exists "read conspiracy rules" on public.conspiracy_rules;
create policy "read conspiracy rules"
on public.conspiracy_rules for select to authenticated
using (is_enabled);

drop policy if exists "read own conspiracy progress" on public.conspiracy_progress;
create policy "read own conspiracy progress"
on public.conspiracy_progress for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "read own conspiracy activity" on public.conspiracy_daily_activity;
create policy "read own conspiracy activity"
on public.conspiracy_daily_activity for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "read involved conspiracy invitations" on public.conspiracy_invitations;
create policy "read involved conspiracy invitations"
on public.conspiracy_invitations for select to authenticated
using (
  inviter_id = (select auth.uid())
  or invitee_id = (select auth.uid())
);

drop policy if exists "read involved conspiracy endorsements" on public.conspiracy_endorsements;
create policy "read involved conspiracy endorsements"
on public.conspiracy_endorsements for select to authenticated
using (
  endorser_id = (select auth.uid())
  or candidate_id = (select auth.uid())
);

insert into public.conspiracy_rules (
  conspiracy_id,
  algorithm_key,
  metric_label,
  target_value,
  unlock_mode,
  effect_key,
  config
)
select
  c.id,
  seed.algorithm_key,
  seed.metric_label,
  seed.target_value,
  seed.unlock_mode,
  seed.effect_key,
  seed.config
from public.conspirations c
join (values
  ('cuervo_negro', 'first_publication', 'Obras publicadas', 1::numeric, 'root', 'root_awakened', '{"event":"published_work"}'::jsonb),
  ('velo_ceniza', 'anonymous_works', 'Obras bajo velo', 7::numeric, 'manual', 'layered_mask', '{"tags":["anonimo","anónimo","seudonimo","seudónimo","alias"]}'::jsonb),
  ('llama_perpetua', 'presence_streak', 'Días consecutivos', 3::numeric, 'manual', 'growing_flame', '{"grace_days":1}'::jsonb),
  ('umbral', 'discipline_breadth', 'Disciplinas activas', 3::numeric, 'manual', 'open_door', '{}'::jsonb),
  ('silencio_rojo', 'descriptionless_works', 'Obras sin descripción', 7::numeric, 'manual', 'silent_profile', '{}'::jsonb),
  ('espejo_partido', 'series_depth', 'Piezas en la serie mayor', 7::numeric, 'manual', 'completed_fragment', '{}'::jsonb),
  ('hueso_y_tinta', 'mixed_text_image', 'Obras de texto e imagen', 5::numeric, 'manual', 'inked_feather', '{}'::jsonb),
  ('luna_hendida', 'night_publications', 'Publicaciones nocturnas', 5::numeric, 'manual', 'split_moon', '{"timezone":"UTC","start_hour":23,"end_hour":6}'::jsonb),
  ('raices_profundas', 'membership_years', 'Años en Corvus', 1::numeric, 'manual', 'root_branches', '{}'::jsonb),
  ('cristal_oscuro', 'vision_comments', 'Comentarios sobre la mirada', 5::numeric, 'manual', 'deep_crystal', '{}'::jsonb),
  ('viento_susurrante', 'distinct_influencers', 'Artistas influenciados', 5::numeric, 'manual', 'reversed_spiral', '{}'::jsonb),
  ('faro_sin_luz', 'direct_discoveries', 'Descubrimientos directos', 10::numeric, 'manual', 'lighthouse_blocks', '{}'::jsonb),
  ('sombra_plegada', 'intense_works', 'Pliegues registrados', 14::numeric, 'manual', 'folded_shadow', '{}'::jsonb),
  ('eco_final', 'closed_cycles', 'Ciclos cerrados', 1::numeric, 'manual', 'final_bell', '{"minimum_pieces":3}'::jsonb),
  ('pacto_de_sangre', 'accepted_invitation', 'Invitación reconocida', 1::numeric, 'invitation', 'blood_pact_channel', '{"annual_invite_limit":1,"expires_days":30}'::jsonb),
  ('reloj_detenido', 'time_loss_comments', 'Momentos que detuvieron el tiempo', 1::numeric, 'automatic', 'stopped_clock', '{}'::jsonb),
  ('abismo_azul', 'continuous_months', 'Meses de progresión continua', 12::numeric, 'automatic', 'abyss_depth', '{"maximum_gap_days":21}'::jsonb),
  ('nombre_prohibido', 'system_works', 'Obras dentro del sistema', 10::numeric, 'automatic', 'practice_seal', '{}'::jsonb),
  ('primer_cuervo', 'founder_endorsements', 'Reconocimientos legendarios', 3::numeric, 'curated', 'open_eye', '{"minimum_account_years":2,"requires_continuity":true}'::jsonb),
  ('dios_olvidado', 'curated_seats', 'Designación opaca', 1::numeric, 'curated', 'absence_mark', '{"maximum_active_members":2,"public_visibility":false}'::jsonb),
  ('imperial', 'mastery_score', 'Índice de dominio', 100::numeric, 'automatic', 'imperial_crown', '{"minimum_works":20,"minimum_months":24}'::jsonb),
  ('eclipse', 'return_signal', 'Regresos reconocidos', 1::numeric, 'curated', 'eclipse_halo', '{"minimum_absence_days":90,"halo_hours":48}'::jsonb)
) as seed(
  code,
  algorithm_key,
  metric_label,
  target_value,
  unlock_mode,
  effect_key,
  config
) on seed.code = c.code
on conflict (conspiracy_id) do update set
  algorithm_key = excluded.algorithm_key,
  metric_label = excluded.metric_label,
  target_value = excluded.target_value,
  unlock_mode = excluded.unlock_mode,
  effect_key = excluded.effect_key,
  config = excluded.config,
  is_enabled = true,
  updated_at = now();

update public.conspirations c
set
  mechanic_key = r.algorithm_key,
  enabled_features = coalesce(c.enabled_features, '{}'::jsonb) || jsonb_build_object(
    'algorithm', r.algorithm_key,
    'effect_key', r.effect_key,
    'metric_label', r.metric_label,
    'target_value', r.target_value,
    'unlock_mode', r.unlock_mode
  ),
  content_version = greatest(c.content_version, 5)
from public.conspiracy_rules r
where r.conspiracy_id = c.id;

create or replace function private.write_conspiracy_progress(
  p_user_id uuid,
  p_code text,
  p_metric numeric,
  p_level integer,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_house public.conspirations%rowtype;
  v_rule public.conspiracy_rules%rowtype;
  v_state text;
  v_unlocked boolean;
  v_affiliated boolean;
  v_new_unlock boolean := false;
  v_inserted integer := 0;
  v_effect_active boolean := false;
begin
  select * into v_house
  from public.conspirations
  where code = p_code and is_active;

  if not found then return; end if;

  select * into v_rule
  from public.conspiracy_rules
  where conspiracy_id = v_house.id and is_enabled;

  if not found then return; end if;

  select exists (
    select 1 from public.conspiracy_unlocks
    where user_id = p_user_id and conspiracy_id = v_house.id
  ) into v_unlocked;

  select exists (
    select 1 from public.conspiracy_affiliations
    where user_id = p_user_id
      and conspiracy_id = v_house.id
      and status = 'active'
  ) into v_affiliated;

  if v_rule.unlock_mode = 'automatic'
     and p_metric >= v_rule.target_value
     and not v_unlocked then
    insert into public.conspiracy_unlocks (
      user_id,
      conspiracy_id,
      granted_by,
      visibility
    ) values (
      p_user_id,
      v_house.id,
      'algorithm:' || v_rule.algorithm_key,
      'visible'
    )
    on conflict (user_id, conspiracy_id) do nothing;

    get diagnostics v_inserted = row_count;
    v_new_unlock := v_inserted > 0;
    v_unlocked := true;
  end if;

  if v_house.rarity = 'root' then
    v_state := case when p_metric >= v_rule.target_value
      then 'awakened' else 'active' end;
  elsif v_unlocked then
    v_state := 'unlocked';
  elsif v_house.rarity = 'free' then
    v_state := case when v_affiliated then 'active' else 'available' end;
  elsif p_code = 'dios_olvidado' then
    v_state := 'hidden';
  elsif v_house.rarity = 'legendary' then
    v_state := case when p_metric >= v_rule.target_value
      then 'candidate' else 'veiled' end;
  else
    v_state := case when p_metric >= v_rule.target_value
      then 'eligible' else 'tracking' end;
  end if;

  v_effect_active := case
    when v_house.rarity = 'root' then v_state = 'awakened'
    when v_house.rarity = 'free' then v_affiliated
    when p_code = 'eclipse' then
      v_unlocked and coalesce((p_details ->> 'halo_active')::boolean, false)
    else v_unlocked
  end;

  insert into public.conspiracy_progress (
    user_id,
    conspiracy_id,
    metric_value,
    target_value,
    level,
    state,
    details,
    evaluated_at
  ) values (
    p_user_id,
    v_house.id,
    greatest(0, p_metric),
    v_rule.target_value,
    greatest(0, p_level),
    v_state,
    coalesce(p_details, '{}'::jsonb) || jsonb_build_object(
      'algorithm_key', v_rule.algorithm_key,
      'effect_key', v_rule.effect_key,
      'metric_label', v_rule.metric_label,
      'unlock_mode', v_rule.unlock_mode,
      'effect_active', v_effect_active
    ),
    now()
  )
  on conflict (user_id, conspiracy_id) do update set
    metric_value = excluded.metric_value,
    target_value = excluded.target_value,
    level = excluded.level,
    state = excluded.state,
    details = excluded.details,
    evaluated_at = excluded.evaluated_at;

  if v_new_unlock then
    insert into public.conspiracy_domain_events (
      event_key,
      user_id,
      conspiracy_id,
      payload
    ) values (
      'conspiracy_unlocked',
      p_user_id,
      v_house.id,
      jsonb_build_object(
        'algorithm_key', v_rule.algorithm_key,
        'metric_value', p_metric,
        'target_value', v_rule.target_value
      )
    );

    insert into public.notifications (
      profile_id,
      kind,
      title,
      body,
      entity_type,
      entity_id
    ) values (
      p_user_id,
      'conspiracy_unlocked',
      'Una conspiración te reconoce',
      v_house.name || ' ha respondido a la evidencia de tu trayectoria.',
      'conspiracy',
      v_house.id
    );
  end if;
end;
$$;

revoke all on function private.write_conspiracy_progress(uuid, text, numeric, integer, jsonb) from public;

create or replace function private.evaluate_conspiracy_progress(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_work_count integer := 0;
  v_anonymous integer := 0;
  v_presence integer := 0;
  v_disciplines integer := 0;
  v_silent integer := 0;
  v_series integer := 0;
  v_mixed integer := 0;
  v_night integer := 0;
  v_years integer := 0;
  v_vision integer := 0;
  v_influencers integer := 0;
  v_direct integer := 0;
  v_intense integer := 0;
  v_cycles integer := 0;
  v_invites integer := 0;
  v_clock integer := 0;
  v_abyss integer := 0;
  v_max_gap integer := 0;
  v_system_documented boolean := false;
  v_system_works integer := 0;
  v_endorsements integer := 0;
  v_age_years integer := 0;
  v_imperial numeric := 0;
  v_span_months numeric := 0;
  v_dominant_ratio numeric := 0;
  v_dominant_tag_count integer := 0;
  v_return integer := 0;
  v_latest_return timestamptz;
  v_dios integer := 0;
begin
  select * into v_profile from public.profiles where id = p_user_id;
  if not found then return; end if;

  v_age_years := greatest(
    0,
    extract(year from age(current_date, v_profile.created_at::date))::integer
  );

  select
    count(*)::integer,
    count(distinct nullif(trim(discipline), ''))::integer,
    count(*) filter (where trim(coalesce(description, '')) = '')::integer,
    count(*) filter (
      where lower(coalesce(aeternum_ficha ->> 'anonymous_attribution', 'false'))
        in ('true', '1', 'yes', 'si', 'sí')
      or exists (
        select 1 from unnest(tags) tag
        where lower(tag) in ('anonimo', 'anónimo', 'seudonimo', 'seudónimo', 'alias')
      )
    )::integer,
    count(*) filter (
      where nullif(trim(coalesce(text_body, '')), '') is not null
        and (
          nullif(trim(coalesce(cover_url, '')), '') is not null
          or cardinality(media_urls) > 0
        )
    )::integer,
    count(*) filter (
      where extract(hour from coalesce(published_at, created_at) at time zone 'UTC') >= 23
         or extract(hour from coalesce(published_at, created_at) at time zone 'UTC') < 6
    )::integer,
    count(*) filter (
      where coalesce(is_mature, false)
         or cardinality(content_warnings) > 0
    )::integer
  into
    v_work_count,
    v_disciplines,
    v_silent,
    v_anonymous,
    v_mixed,
    v_night,
    v_intense
  from public.works
  where profile_id = p_user_id
    and status = 'published'
    and is_public;

  select coalesce(max(series_size), 0)::integer into v_series
  from (
    select count(*)::integer as series_size
    from public.collections c
    join public.collection_items ci on ci.collection_id = c.id
    where c.profile_id = p_user_id and c.collection_type = 'series'
    group by c.id
    union all
    select count(*)::integer
    from public.works w
    where w.profile_id = p_user_id
      and w.root_work_id is not null
      and w.status = 'published'
      and w.is_public
    group by w.root_work_id
  ) series;

  with ordered as (
    select
      activity_date,
      activity_date - (row_number() over (order by activity_date))::integer as island
    from public.conspiracy_daily_activity
    where user_id = p_user_id
  ), streaks as (
    select count(*)::integer as days, max(activity_date) as last_day
    from ordered
    group by island
  )
  select coalesce(max(days) filter (where last_day >= current_date - 1), 0)
  into v_presence
  from streaks;

  v_years := v_age_years;

  select count(*)::integer into v_vision
  from public.work_comments wc
  join public.works w on w.id = wc.work_id
  where w.profile_id = p_user_id
    and not wc.is_deleted
    and lower(wc.body) ~ '(forma en que ves|forma de ver|tu mirada|perspectiva|modo de mirar)';

  select count(distinct payload ->> 'actor_id')::integer into v_influencers
  from public.conspiracy_domain_events
  where user_id = p_user_id
    and event_key = 'influence_mentioned'
    and nullif(payload ->> 'actor_id', '') is not null;

  select count(*)::integer into v_direct
  from public.conspiracy_domain_events
  where user_id = p_user_id and event_key = 'direct_profile_discovery';

  select count(*)::integer into v_cycles
  from (
    select c.id
    from public.collections c
    join public.collection_items ci on ci.collection_id = c.id
    join public.works w on w.id = ci.work_id
    where c.profile_id = p_user_id and c.collection_type = 'series'
    group by c.id
    having count(*) >= 3 and bool_and(coalesce(w.is_complete, false))
  ) closed_series;

  select count(*)::integer into v_invites
  from public.conspiracy_invitations i
  join public.conspirations c on c.id = i.conspiracy_id
  where i.invitee_id = p_user_id
    and i.status = 'accepted'
    and c.code = 'pacto_de_sangre';

  select count(*)::integer into v_clock
  from public.work_comments wc
  join public.works w on w.id = wc.work_id
  where w.profile_id = p_user_id
    and not wc.is_deleted
    and lower(wc.body) ~ '(perdi el tiempo|perdí el tiempo|perder la nocion|perder la noción|detuvo el tiempo|horas mirando|olvide el tiempo|olvidé el tiempo)';

  with dates as (
    select distinct coalesce(published_at, created_at)::date as published_date
    from public.works
    where profile_id = p_user_id and status = 'published' and is_public
  ), gaps as (
    select
      published_date,
      published_date - lag(published_date) over (order by published_date) as gap_days
    from dates
  ), grouped as (
    select
      published_date,
      gap_days,
      sum(case when gap_days > 21 then 1 else 0 end)
        over (order by published_date) as streak_group
    from gaps
  ), streaks as (
    select
      greatest(1, floor((max(published_date) - min(published_date)) / 30.0) + 1)::integer as months
    from grouped
    group by streak_group
  )
  select coalesce(max(months), 0) into v_abyss from streaks;

  select coalesce(max(gap_days), 0)::integer into v_max_gap
  from (
    select
      published_date - lag(published_date) over (order by published_date) as gap_days
    from (
      select distinct coalesce(published_at, created_at)::date as published_date
      from public.works
      where profile_id = p_user_id and status = 'published' and is_public
    ) ordered_dates
  ) gaps;

  select exists (
    select 1 from public.atelier_nodes
    where profile_id = p_user_id
      and (
        kind = 'system'
        or nullif(trim(coalesce(metadata ->> 'practice_system', '')), '') is not null
      )
  ) into v_system_documented;

  if v_system_documented then
    select count(*)::integer into v_system_works
    from public.works
    where profile_id = p_user_id
      and status = 'published'
      and is_public
      and (
        nullif(trim(coalesce(aeternum_ficha ->> 'practice_system', '')), '') is not null
        or exists (
          select 1 from unnest(tags) tag
          where lower(tag) in ('sistema', 'system', 'regla', 'metodo', 'método')
        )
      );
  end if;

  select count(*)::integer into v_endorsements
  from public.conspiracy_endorsements e
  join public.conspirations c on c.id = e.conspiracy_id
  where e.candidate_id = p_user_id and c.code = 'primer_cuervo';

  select greatest(
    0,
    extract(epoch from (
      max(coalesce(published_at, created_at)) - min(coalesce(published_at, created_at))
    )) / 2629800.0
  ) into v_span_months
  from public.works
  where profile_id = p_user_id and status = 'published' and is_public;

  select coalesce(max(discipline_count)::numeric / nullif(v_work_count, 0), 0)
  into v_dominant_ratio
  from (
    select count(*)::integer as discipline_count
    from public.works
    where profile_id = p_user_id and status = 'published' and is_public
    group by lower(trim(discipline))
  ) discipline_counts;

  select coalesce(max(tag_count), 0)::integer into v_dominant_tag_count
  from (
    select lower(trim(tag)) as normalized_tag, count(*)::integer as tag_count
    from public.works w cross join lateral unnest(w.tags) tag
    where w.profile_id = p_user_id and w.status = 'published' and w.is_public
      and nullif(trim(tag), '') is not null
    group by lower(trim(tag))
  ) tag_counts;

  v_imperial :=
    least(40, v_work_count * 2)
    + least(25, floor(coalesce(v_span_months, 0) / 24.0 * 25))
    + case when v_work_count >= 5 and v_dominant_ratio >= 0.60 then 20 else 0 end
    + case when v_dominant_tag_count >= 5 then 15 else 0 end;

  select count(*)::integer, max(created_at) into v_return, v_latest_return
  from public.conspiracy_domain_events
  where user_id = p_user_id and event_key = 'artist_return_detected';

  select count(*)::integer into v_dios
  from public.conspiracy_unlocks u
  join public.conspirations c on c.id = u.conspiracy_id
  where u.user_id = p_user_id and c.code = 'dios_olvidado';

  perform private.write_conspiracy_progress(p_user_id, 'cuervo_negro', v_work_count, least(v_work_count, 1), jsonb_build_object('published_works', v_work_count));
  perform private.write_conspiracy_progress(p_user_id, 'velo_ceniza', v_anonymous, v_anonymous / 7, jsonb_build_object('anonymous_works', v_anonymous));
  perform private.write_conspiracy_progress(p_user_id, 'llama_perpetua', v_presence, v_presence / 3, jsonb_build_object('current_streak_days', v_presence));
  perform private.write_conspiracy_progress(p_user_id, 'umbral', v_disciplines, v_disciplines, jsonb_build_object('distinct_disciplines', v_disciplines));
  perform private.write_conspiracy_progress(p_user_id, 'silencio_rojo', v_silent, v_silent / 7, jsonb_build_object('descriptionless_works', v_silent));
  perform private.write_conspiracy_progress(p_user_id, 'espejo_partido', v_series, v_series / 7, jsonb_build_object('largest_series', v_series));
  perform private.write_conspiracy_progress(p_user_id, 'hueso_y_tinta', v_mixed, v_mixed / 5, jsonb_build_object('mixed_works', v_mixed));
  perform private.write_conspiracy_progress(p_user_id, 'luna_hendida', v_night, v_night / 5, jsonb_build_object('night_works', v_night, 'timezone', 'UTC'));
  perform private.write_conspiracy_progress(p_user_id, 'raices_profundas', v_years, v_years, jsonb_build_object('membership_years', v_years));
  perform private.write_conspiracy_progress(p_user_id, 'cristal_oscuro', v_vision, v_vision / 5, jsonb_build_object('vision_comments', v_vision));
  perform private.write_conspiracy_progress(p_user_id, 'viento_susurrante', v_influencers, v_influencers / 5, jsonb_build_object('distinct_influencers', v_influencers));
  perform private.write_conspiracy_progress(p_user_id, 'faro_sin_luz', v_direct, v_direct / 10, jsonb_build_object('direct_discoveries', v_direct));
  perform private.write_conspiracy_progress(p_user_id, 'sombra_plegada', v_intense, v_intense / 14, jsonb_build_object('intense_works', v_intense));
  perform private.write_conspiracy_progress(p_user_id, 'eco_final', v_cycles, v_cycles, jsonb_build_object('closed_cycles', v_cycles));
  perform private.write_conspiracy_progress(p_user_id, 'pacto_de_sangre', v_invites, v_invites, jsonb_build_object('accepted_invitations', v_invites));
  perform private.write_conspiracy_progress(p_user_id, 'reloj_detenido', v_clock, v_clock, jsonb_build_object('time_loss_comments', v_clock));
  perform private.write_conspiracy_progress(p_user_id, 'abismo_azul', v_abyss, v_abyss / 12, jsonb_build_object('continuous_months', v_abyss, 'maximum_gap_days', v_max_gap));
  perform private.write_conspiracy_progress(p_user_id, 'nombre_prohibido', v_system_works, v_system_works / 10, jsonb_build_object('system_documented', v_system_documented, 'system_works', v_system_works));
  perform private.write_conspiracy_progress(p_user_id, 'primer_cuervo', case when v_age_years >= 2 and v_abyss >= 12 then v_endorsements else 0 end, v_endorsements, jsonb_build_object('endorsements', v_endorsements, 'account_years', v_age_years, 'continuity_months', v_abyss));
  perform private.write_conspiracy_progress(p_user_id, 'dios_olvidado', v_dios, v_dios, jsonb_build_object('opaque', true));
  perform private.write_conspiracy_progress(p_user_id, 'imperial', v_imperial, floor(v_imperial / 25)::integer, jsonb_build_object('mastery_score', v_imperial, 'published_works', v_work_count, 'practice_span_months', round(v_span_months, 1), 'dominant_discipline_ratio', round(v_dominant_ratio, 2), 'dominant_tag_works', v_dominant_tag_count));
  perform private.write_conspiracy_progress(p_user_id, 'eclipse', v_return, v_return, jsonb_build_object(
    'return_signals', v_return,
    'latest_return_at', v_latest_return,
    'halo_active', v_latest_return is not null and v_latest_return >= now() - interval '48 hours',
    'halo_expires_at', case when v_latest_return is null then null else v_latest_return + interval '48 hours' end
  ));
end;
$$;

revoke all on function private.evaluate_conspiracy_progress(uuid) from public;

create or replace function public.get_my_conspiracy_progress()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  return jsonb_build_object(
    'ok', true,
    'progress', coalesce((
      select jsonb_agg(jsonb_build_object(
        'conspiracy_id', p.conspiracy_id,
        'code', c.code,
        'name', c.name,
        'metric_value', p.metric_value,
        'target_value', p.target_value,
        'level', p.level,
        'state', p.state,
        'details', p.details,
        'evaluated_at', p.evaluated_at
      ) order by c.sort_order)
      from public.conspiracy_progress p
      join public.conspirations c on c.id = p.conspiracy_id
      where p.user_id = v_user_id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_my_conspiracy_progress() from public;
revoke all on function public.get_my_conspiracy_progress() from anon;
grant execute on function public.get_my_conspiracy_progress() to authenticated;

create or replace function public.refresh_my_conspiracy_progress()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;
  perform private.evaluate_conspiracy_progress(v_user_id);
  return public.get_my_conspiracy_progress();
end;
$$;

revoke all on function public.refresh_my_conspiracy_progress() from public;
revoke all on function public.refresh_my_conspiracy_progress() from anon;
grant execute on function public.refresh_my_conspiracy_progress() to authenticated;

create or replace function public.record_conspiracy_presence()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  insert into public.conspiracy_daily_activity (
    user_id,
    activity_date,
    first_seen_at,
    last_seen_at,
    source
  ) values (
    v_user_id,
    current_date,
    now(),
    now(),
    'app'
  )
  on conflict (user_id, activity_date) do update set
    last_seen_at = excluded.last_seen_at;

  perform private.evaluate_conspiracy_progress(v_user_id);
  return public.get_my_conspiracy_progress();
end;
$$;

revoke all on function public.record_conspiracy_presence() from public;
revoke all on function public.record_conspiracy_presence() from anon;
grant execute on function public.record_conspiracy_presence() to authenticated;

create unique index if not exists conspiracy_social_signal_actor_idx
  on public.conspiracy_domain_events(
    user_id,
    event_key,
    ((payload ->> 'actor_id'))
  )
  where event_key in ('influence_mentioned', 'direct_profile_discovery')
    and nullif(payload ->> 'actor_id', '') is not null;

create or replace function public.record_conspiracy_signal(
  p_signal_key text,
  p_target_profile_id uuid,
  p_evidence_work_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_inserted integer := 0;
begin
  if v_actor_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;
  if p_signal_key not in ('influence_mentioned', 'direct_profile_discovery') then
    return jsonb_build_object('ok', false, 'reason_code', 'INVALID_SIGNAL');
  end if;
  if p_target_profile_id = v_actor_id then
    return jsonb_build_object('ok', false, 'reason_code', 'SELF_SIGNAL');
  end if;
  if not exists (
    select 1 from public.profiles where id = p_target_profile_id
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'PROFILE_NOT_FOUND');
  end if;
  if p_evidence_work_id is not null and not exists (
    select 1
    from public.works
    where id = p_evidence_work_id
      and profile_id = p_target_profile_id
      and status = 'published'
      and is_public
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'INVALID_EVIDENCE');
  end if;

  insert into public.conspiracy_domain_events (
    event_key,
    user_id,
    payload
  ) values (
    p_signal_key,
    p_target_profile_id,
    jsonb_build_object(
      'actor_id', v_actor_id,
      'evidence_work_id', p_evidence_work_id,
      'source', 'authenticated_client'
    )
  ) on conflict do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    perform private.evaluate_conspiracy_progress(p_target_profile_id);
  end if;

  return jsonb_build_object(
    'ok', true,
    'recorded', v_inserted > 0
  );
end;
$$;

revoke all on function public.record_conspiracy_signal(text, uuid, uuid) from public;
revoke all on function public.record_conspiracy_signal(text, uuid, uuid) from anon;
grant execute on function public.record_conspiracy_signal(text, uuid, uuid) to authenticated;

create or replace function public.create_blood_pact_invitation(
  p_invitee_id uuid,
  p_evidence_work_id uuid default null,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inviter_id uuid := auth.uid();
  v_house_id uuid;
  v_invitation_id uuid;
begin
  if v_inviter_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;
  if p_invitee_id = v_inviter_id then
    return jsonb_build_object('ok', false, 'reason_code', 'SELF_INVITATION');
  end if;
  if char_length(coalesce(p_note, '')) > 1000 then
    return jsonb_build_object('ok', false, 'reason_code', 'NOTE_TOO_LONG');
  end if;

  select id into v_house_id
  from public.conspirations
  where code = 'pacto_de_sangre' and is_active;

  if v_house_id is null or not exists (
    select 1
    from public.conspiracy_unlocks
    where user_id = v_inviter_id and conspiracy_id = v_house_id
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'INVITER_NOT_MEMBER');
  end if;
  if not exists (select 1 from public.profiles where id = p_invitee_id) then
    return jsonb_build_object('ok', false, 'reason_code', 'PROFILE_NOT_FOUND');
  end if;
  if exists (
    select 1
    from public.conspiracy_unlocks
    where user_id = p_invitee_id and conspiracy_id = v_house_id
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ALREADY_MEMBER');
  end if;
  if exists (
    select 1
    from public.conspiracy_invitations
    where conspiracy_id = v_house_id
      and inviter_id = v_inviter_id
      and created_at >= date_trunc('year', now())
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ANNUAL_INVITE_USED');
  end if;
  if p_evidence_work_id is not null and not exists (
    select 1
    from public.works
    where id = p_evidence_work_id
      and profile_id = p_invitee_id
      and status = 'published'
      and is_public
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'INVALID_EVIDENCE');
  end if;

  update public.conspiracy_invitations
  set status = 'expired', responded_at = now()
  where conspiracy_id = v_house_id
    and invitee_id = p_invitee_id
    and status = 'pending'
    and expires_at <= now();

  insert into public.conspiracy_invitations (
    conspiracy_id,
    inviter_id,
    invitee_id,
    evidence_work_id,
    note
  ) values (
    v_house_id,
    v_inviter_id,
    p_invitee_id,
    p_evidence_work_id,
    coalesce(p_note, '')
  ) returning id into v_invitation_id;

  insert into public.conspiracy_domain_events (
    event_key,
    user_id,
    conspiracy_id,
    payload
  ) values (
    'blood_pact_invited',
    p_invitee_id,
    v_house_id,
    jsonb_build_object(
      'invitation_id', v_invitation_id,
      'actor_id', v_inviter_id,
      'evidence_work_id', p_evidence_work_id
    )
  );

  insert into public.notifications (
    profile_id,
    kind,
    title,
    body,
    actor_id,
    entity_type,
    entity_id
  ) values (
    p_invitee_id,
    'conspiracy_invitation',
    'Una invitación sellada en sangre',
    'Un miembro del Pacto de Sangre ha pronunciado tu nombre.',
    v_inviter_id,
    'conspiracy',
    v_house_id
  );

  return jsonb_build_object(
    'ok', true,
    'invitation_id', v_invitation_id,
    'expires_at', now() + interval '30 days'
  );
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'reason_code', 'INVITATION_PENDING');
end;
$$;

revoke all on function public.create_blood_pact_invitation(uuid, uuid, text) from public;
revoke all on function public.create_blood_pact_invitation(uuid, uuid, text) from anon;
grant execute on function public.create_blood_pact_invitation(uuid, uuid, text) to authenticated;

create or replace function public.respond_blood_pact_invitation(
  p_invitation_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_invitation public.conspiracy_invitations%rowtype;
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  select * into v_invitation
  from public.conspiracy_invitations
  where id = p_invitation_id
  for update;

  if not found or v_invitation.invitee_id <> v_user_id then
    return jsonb_build_object('ok', false, 'reason_code', 'INVITATION_NOT_FOUND');
  end if;
  if v_invitation.status <> 'pending' then
    return jsonb_build_object('ok', false, 'reason_code', 'INVITATION_RESOLVED');
  end if;
  if v_invitation.expires_at <= now() then
    update public.conspiracy_invitations
    set status = 'expired', responded_at = now()
    where id = p_invitation_id;
    return jsonb_build_object('ok', false, 'reason_code', 'INVITATION_EXPIRED');
  end if;

  update public.conspiracy_invitations
  set
    status = case when p_accept then 'accepted' else 'declined' end,
    responded_at = now()
  where id = p_invitation_id;

  if p_accept then
    insert into public.conspiracy_unlocks (
      user_id,
      conspiracy_id,
      granted_by,
      visibility
    ) values (
      v_user_id,
      v_invitation.conspiracy_id,
      'invitation:' || p_invitation_id::text,
      'visible'
    ) on conflict (user_id, conspiracy_id) do nothing;

    insert into public.conspiracy_domain_events (
      event_key,
      user_id,
      conspiracy_id,
      payload
    ) values (
      'blood_pact_accepted',
      v_user_id,
      v_invitation.conspiracy_id,
      jsonb_build_object(
        'invitation_id', p_invitation_id,
        'actor_id', v_invitation.inviter_id,
        'evidence_work_id', v_invitation.evidence_work_id
      )
    );

    insert into public.notifications (
      profile_id,
      kind,
      title,
      body,
      actor_id,
      entity_type,
      entity_id
    ) values (
      v_user_id,
      'conspiracy_unlocked',
      'El Pacto te reconoce',
      'La invitación fue aceptada. El canal del Pacto de Sangre se ha abierto.',
      v_invitation.inviter_id,
      'conspiracy',
      v_invitation.conspiracy_id
    );

    perform private.evaluate_conspiracy_progress(v_user_id);
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', case when p_accept then 'accepted' else 'declined' end
  );
end;
$$;

revoke all on function public.respond_blood_pact_invitation(uuid, boolean) from public;
revoke all on function public.respond_blood_pact_invitation(uuid, boolean) from anon;
grant execute on function public.respond_blood_pact_invitation(uuid, boolean) to authenticated;

create or replace function public.endorse_first_crow(
  p_candidate_id uuid,
  p_evidence_work_id uuid,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_endorser_id uuid := auth.uid();
  v_house_id uuid;
  v_endorsement_id uuid;
begin
  if v_endorser_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;
  if p_candidate_id = v_endorser_id then
    return jsonb_build_object('ok', false, 'reason_code', 'SELF_ENDORSEMENT');
  end if;
  if char_length(trim(coalesce(p_note, ''))) < 1
     or char_length(p_note) > 1200 then
    return jsonb_build_object('ok', false, 'reason_code', 'INVALID_NOTE');
  end if;

  select id into v_house_id
  from public.conspirations
  where code = 'primer_cuervo' and is_active;

  if v_house_id is null or not exists (
    select 1
    from public.conspiracy_unlocks
    where user_id = v_endorser_id and conspiracy_id = v_house_id
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ENDORSER_NOT_RECOGNIZED');
  end if;
  if not exists (
    select 1
    from public.profiles
    where id = p_candidate_id
      and created_at <= now() - interval '2 years'
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'CANDIDATE_NOT_ELIGIBLE');
  end if;

  perform private.evaluate_conspiracy_progress(p_candidate_id);
  if not exists (
    select 1
    from public.conspiracy_progress progress
    join public.conspirations house on house.id = progress.conspiracy_id
    where progress.user_id = p_candidate_id
      and house.code = 'abismo_azul'
      and progress.metric_value >= progress.target_value
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'CANDIDATE_NOT_CONTINUOUS');
  end if;
  if not exists (
    select 1
    from public.works
    where id = p_evidence_work_id
      and profile_id = p_candidate_id
      and status = 'published'
      and is_public
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'INVALID_EVIDENCE');
  end if;

  insert into public.conspiracy_endorsements (
    conspiracy_id,
    endorser_id,
    candidate_id,
    evidence_work_id,
    note
  ) values (
    v_house_id,
    v_endorser_id,
    p_candidate_id,
    p_evidence_work_id,
    trim(p_note)
  ) returning id into v_endorsement_id;

  insert into public.conspiracy_domain_events (
    event_key,
    user_id,
    conspiracy_id,
    payload
  ) values (
    'first_crow_endorsed',
    p_candidate_id,
    v_house_id,
    jsonb_build_object(
      'endorsement_id', v_endorsement_id,
      'actor_id', v_endorser_id,
      'evidence_work_id', p_evidence_work_id
    )
  );

  perform private.evaluate_conspiracy_progress(p_candidate_id);
  return jsonb_build_object('ok', true, 'endorsement_id', v_endorsement_id);
exception
  when unique_violation then
    return jsonb_build_object('ok', false, 'reason_code', 'ALREADY_ENDORSED');
end;
$$;

revoke all on function public.endorse_first_crow(uuid, uuid, text) from public;
revoke all on function public.endorse_first_crow(uuid, uuid, text) from anon;
grant execute on function public.endorse_first_crow(uuid, uuid, text) to authenticated;

create or replace function public.grant_curated_conspiracy(
  p_target_user_id uuid,
  p_target_conspiracy_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_house public.conspirations%rowtype;
  v_unlock_id uuid;
  v_correlation_id uuid := gen_random_uuid();
  v_visibility text := 'visible';
begin
  if v_actor_id is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;
  if not exists (
    select 1 from private.conspiracy_curators
    where user_id = v_actor_id
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;
  if char_length(trim(coalesce(p_reason, ''))) < 10
     or char_length(p_reason) > 2000 then
    return jsonb_build_object('ok', false, 'reason_code', 'INVALID_REASON');
  end if;
  if not exists (select 1 from public.profiles where id = p_target_user_id) then
    return jsonb_build_object('ok', false, 'reason_code', 'PROFILE_NOT_FOUND');
  end if;

  select * into v_house
  from public.conspirations
  where id = p_target_conspiracy_id and is_active
  for update;

  if not found or v_house.rarity <> 'legendary' then
    return jsonb_build_object('ok', false, 'reason_code', 'HOUSE_NOT_CURATED');
  end if;
  if exists (
    select 1 from public.conspiracy_unlocks
    where user_id = p_target_user_id and conspiracy_id = v_house.id
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'ALREADY_GRANTED');
  end if;
  if v_house.code = 'dios_olvidado' and (
    select count(*) from public.conspiracy_unlocks
    where conspiracy_id = v_house.id
  ) >= 2 then
    return jsonb_build_object('ok', false, 'reason_code', 'SEAT_LIMIT_REACHED');
  end if;

  perform private.evaluate_conspiracy_progress(p_target_user_id);
  if v_house.code in ('primer_cuervo', 'eclipse') and not exists (
    select 1
    from public.conspiracy_progress
    where user_id = p_target_user_id
      and conspiracy_id = v_house.id
      and state = 'candidate'
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'CANDIDATE_NOT_ELIGIBLE');
  end if;

  if v_house.code = 'dios_olvidado' then
    v_visibility := 'hidden';
  end if;

  insert into public.conspiracy_unlocks (
    user_id,
    conspiracy_id,
    granted_by,
    visibility
  ) values (
    p_target_user_id,
    v_house.id,
    'curator:' || v_actor_id::text,
    v_visibility
  ) returning id into v_unlock_id;

  insert into public.conspiracy_audit_log (
    actor_id,
    action,
    object_type,
    object_id,
    reason,
    after_state,
    correlation_id
  ) values (
    v_actor_id,
    'curated_conspiracy_granted',
    'conspiracy_unlock',
    v_unlock_id::text,
    trim(p_reason),
    jsonb_build_object(
      'user_id', p_target_user_id,
      'conspiracy_id', v_house.id,
      'code', v_house.code,
      'visibility', v_visibility
    ),
    v_correlation_id
  );

  insert into public.conspiracy_domain_events (
    event_key,
    user_id,
    conspiracy_id,
    payload,
    correlation_id
  ) values (
    'curated_conspiracy_granted',
    p_target_user_id,
    v_house.id,
    jsonb_build_object('actor_id', v_actor_id, 'unlock_id', v_unlock_id),
    v_correlation_id
  );

  if v_house.code <> 'dios_olvidado' then
    insert into public.notifications (
      profile_id,
      kind,
      title,
      body,
      entity_type,
      entity_id
    ) values (
      p_target_user_id,
      'conspiracy_unlocked',
      'Una Casa legendaria pronuncia tu nombre',
      v_house.name || ' ha sido incorporada a tu legado.',
      'conspiracy',
      v_house.id
    );
  end if;

  perform private.evaluate_conspiracy_progress(p_target_user_id);
  return jsonb_build_object(
    'ok', true,
    'unlock_id', v_unlock_id,
    'correlation_id', v_correlation_id
  );
end;
$$;

revoke all on function public.grant_curated_conspiracy(uuid, uuid, text) from public;
revoke all on function public.grant_curated_conspiracy(uuid, uuid, text) from anon;
grant execute on function public.grant_curated_conspiracy(uuid, uuid, text) to authenticated;

create or replace function private.handle_conspiracy_work_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_previous_user_id uuid;
  v_publication_at timestamptz;
  v_previous_publication timestamptz;
  v_became_public boolean := false;
begin
  if tg_op = 'DELETE' then
    v_user_id := old.profile_id;
  else
    v_user_id := new.profile_id;
    v_publication_at := coalesce(new.published_at, new.created_at);
    v_became_public := new.status = 'published'
      and new.is_public
      and (
        tg_op = 'INSERT'
        or old.status is distinct from 'published'
        or old.is_public is distinct from true
      );
  end if;

  if v_became_public then
    select max(coalesce(w.published_at, w.created_at))
    into v_previous_publication
    from public.works w
    where w.profile_id = v_user_id
      and w.id <> new.id
      and w.status = 'published'
      and w.is_public
      and coalesce(w.published_at, w.created_at) < v_publication_at;

    if v_previous_publication <= v_publication_at - interval '90 days' then
      insert into public.conspiracy_domain_events (
        event_key,
        user_id,
        payload
      ) values (
        'artist_return_detected',
        v_user_id,
        jsonb_build_object(
          'work_id', new.id,
          'previous_publication_at', v_previous_publication,
          'absence_days', floor(extract(epoch from (
            v_publication_at - v_previous_publication
          )) / 86400)::integer
        )
      ) on conflict do nothing;
    end if;
  end if;

  if v_user_id is not null then
    perform private.evaluate_conspiracy_progress(v_user_id);
  end if;

  if tg_op = 'UPDATE' then
    v_previous_user_id := old.profile_id;
    if v_previous_user_id is distinct from v_user_id
       and v_previous_user_id is not null then
      perform private.evaluate_conspiracy_progress(v_previous_user_id);
    end if;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function private.handle_conspiracy_comment_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_work_id uuid;
  v_owner_id uuid;
  v_actor_id uuid;
  v_body text;
  v_deleted boolean;
begin
  if tg_op = 'DELETE' then
    v_work_id := old.work_id;
    v_actor_id := old.profile_id;
    v_body := old.body;
    v_deleted := old.is_deleted;
  else
    v_work_id := new.work_id;
    v_actor_id := new.profile_id;
    v_body := new.body;
    v_deleted := new.is_deleted;
  end if;

  select profile_id into v_owner_id
  from public.works
  where id = v_work_id;

  if v_owner_id is not null then
    if tg_op <> 'DELETE'
       and not v_deleted
       and v_actor_id is distinct from v_owner_id
       and lower(v_body) ~ '(me inspir|me influy|influencia en mi|cambio mi forma de crear|cambió mi forma de crear)' then
      insert into public.conspiracy_domain_events (
        event_key,
        user_id,
        payload
      ) values (
        'influence_mentioned',
        v_owner_id,
        jsonb_build_object(
          'actor_id', v_actor_id,
          'comment_id', new.id,
          'evidence_work_id', v_work_id,
          'source', 'comment'
        )
      ) on conflict do nothing;
    end if;
    perform private.evaluate_conspiracy_progress(v_owner_id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function private.handle_conspiracy_collection_item_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_collection_id uuid;
  v_owner_id uuid;
begin
  v_collection_id := case when tg_op = 'DELETE'
    then old.collection_id else new.collection_id end;
  select profile_id into v_owner_id
  from public.collections
  where id = v_collection_id;
  if v_owner_id is not null then
    perform private.evaluate_conspiracy_progress(v_owner_id);
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function private.handle_conspiracy_atelier_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  v_user_id := case when tg_op = 'DELETE'
    then old.profile_id else new.profile_id end;
  if v_user_id is not null then
    perform private.evaluate_conspiracy_progress(v_user_id);
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function private.handle_conspiracy_work_change() from public;
revoke all on function private.handle_conspiracy_comment_change() from public;
revoke all on function private.handle_conspiracy_collection_item_change() from public;
revoke all on function private.handle_conspiracy_atelier_change() from public;

drop trigger if exists evaluate_conspiracies_after_work on public.works;
create trigger evaluate_conspiracies_after_work
after insert or update or delete on public.works
for each row execute function private.handle_conspiracy_work_change();

drop trigger if exists evaluate_conspiracies_after_comment on public.work_comments;
create trigger evaluate_conspiracies_after_comment
after insert or update or delete on public.work_comments
for each row execute function private.handle_conspiracy_comment_change();

drop trigger if exists evaluate_conspiracies_after_collection_item on public.collection_items;
create trigger evaluate_conspiracies_after_collection_item
after insert or update or delete on public.collection_items
for each row execute function private.handle_conspiracy_collection_item_change();

drop trigger if exists evaluate_conspiracies_after_atelier_node on public.atelier_nodes;
create trigger evaluate_conspiracies_after_atelier_node
after insert or update or delete on public.atelier_nodes
for each row execute function private.handle_conspiracy_atelier_change();

create or replace function private.refresh_all_conspiracy_progress()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  update public.conspiracy_invitations
  set status = 'expired', responded_at = now()
  where status = 'pending' and expires_at <= now();

  for v_user_id in select id from public.profiles loop
    perform private.evaluate_conspiracy_progress(v_user_id);
  end loop;
end;
$$;

revoke all on function private.refresh_all_conspiracy_progress() from public;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'refresh-conspiracy-progress-nightly';
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
  perform cron.schedule(
    'refresh-conspiracy-progress-nightly',
    '17 3 * * *',
    'select private.refresh_all_conspiracy_progress()'
  );
end;
$$;

select private.refresh_all_conspiracy_progress();
