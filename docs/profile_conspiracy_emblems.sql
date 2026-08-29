-- Read model for the emblem showcase on own and public profiles.
create or replace function public.get_profile_conspiracy_emblems(
  p_profile_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select case
    when (select auth.uid()) is null then
      jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED')
    when not exists (
      select 1 from public.profiles p where p.id = p_profile_id
    ) then
      jsonb_build_object('ok', false, 'reason_code', 'PROFILE_NOT_FOUND')
    else
      jsonb_build_object(
        'ok', true,
        'root', (
          select jsonb_build_object(
            'id', c.id,
            'code', c.code,
            'name', c.name,
            'registry_number', c.registry_number,
            'rarity', c.rarity,
            'symbol', c.symbol,
            'lore', c.lore,
            'accent_hex', c.accent_hex,
            'glow_hex', c.glow_hex
          )
          from public.conspirations c
          where c.code = 'cuervo_negro' and c.is_active
          limit 1
        ),
        'primary', (
          select jsonb_build_object(
            'id', c.id,
            'code', c.code,
            'name', c.name,
            'registry_number', c.registry_number,
            'rarity', c.rarity,
            'symbol', c.symbol,
            'lore', c.lore,
            'accent_hex', c.accent_hex,
            'glow_hex', c.glow_hex,
            'joined_at', a.joined_at,
            'role', 'primary'
          )
          from public.conspiracy_affiliations a
          join public.conspirations c on c.id = a.conspiracy_id
          where a.user_id = p_profile_id
            and a.role = 'primary'
            and a.status = 'active'
            and c.is_active
          order by a.joined_at desc
          limit 1
        ),
        'secondaries', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', c.id,
              'code', c.code,
              'name', c.name,
              'registry_number', c.registry_number,
              'rarity', c.rarity,
              'symbol', c.symbol,
              'lore', c.lore,
              'accent_hex', c.accent_hex,
              'glow_hex', c.glow_hex,
              'joined_at', a.joined_at,
              'role', 'secondary'
            )
            order by a.joined_at
          )
          from public.conspiracy_affiliations a
          join public.conspirations c on c.id = a.conspiracy_id
          where a.user_id = p_profile_id
            and a.role = 'secondary'
            and a.status = 'active'
            and c.is_active
        ), '[]'::jsonb),
        'unlocks', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', c.id,
              'code', c.code,
              'name', c.name,
              'registry_number', c.registry_number,
              'rarity', c.rarity,
              'symbol', c.symbol,
              'lore', c.lore,
              'accent_hex', c.accent_hex,
              'glow_hex', c.glow_hex,
              'unlocked_at', u.unlocked_at
            )
            order by u.unlocked_at
          )
          from public.conspiracy_unlocks u
          join public.conspirations c on c.id = u.conspiracy_id
          where u.user_id = p_profile_id
            and c.is_active
            and (
              u.visibility = 'visible'
              or u.user_id = (select auth.uid())
            )
        ), '[]'::jsonb),
        'history', '[]'::jsonb
      )
  end
$function$;

revoke execute on function public.get_profile_conspiracy_emblems(uuid)
from public, anon;
grant execute on function public.get_profile_conspiracy_emblems(uuid)
to authenticated, service_role;

comment on function public.get_profile_conspiracy_emblems(uuid) is
  'Returns the profile-safe conspiracy emblems for an authenticated viewer.';
