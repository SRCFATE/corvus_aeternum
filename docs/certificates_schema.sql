-- Corvus Aeternum / Verifiable certificates and provenance

create extension if not exists pgcrypto;

create sequence if not exists public.aeternum_certificate_number_seq;

create table if not exists public.aeternum_certificates (
  id uuid primary key default gen_random_uuid(),
  certificate_number text not null unique,
  verification_code uuid not null default gen_random_uuid(),
  work_id uuid not null references public.works(id) on delete restrict,
  auction_id uuid references public.auctions(id) on delete set null,
  issuer_profile_id uuid not null references public.profiles(id) on delete restrict,
  owner_profile_id uuid references public.profiles(id) on delete set null,
  status text not null default 'active',
  edition_label text not null default 'Original',
  title_snapshot text not null,
  artist_snapshot text not null,
  year smallint,
  discipline text not null default '',
  technique text not null default '',
  dimensions text not null default '',
  owner_public boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  issued_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint aeternum_certificates_status_check
    check (status in ('active', 'transferred', 'revoked')),
  constraint aeternum_certificates_number_check
    check (certificate_number ~ '^CA-[0-9]{4}-[0-9]{6}$'),
  constraint aeternum_certificates_edition_check
    check (char_length(btrim(edition_label)) between 1 and 80)
);

create table if not exists public.certificate_events (
  id uuid primary key default gen_random_uuid(),
  certificate_id uuid not null
    references public.aeternum_certificates(id) on delete cascade,
  event_type text not null,
  actor_id uuid references public.profiles(id) on delete set null,
  from_owner_id uuid references public.profiles(id) on delete set null,
  to_owner_id uuid references public.profiles(id) on delete set null,
  auction_id uuid references public.auctions(id) on delete set null,
  note text not null default '',
  created_at timestamptz not null default now(),
  constraint certificate_events_type_check check (
    event_type in (
      'issued', 'auction_awarded', 'transferred', 'revoked', 'privacy_changed'
    )
  )
);

create unique index if not exists aeternum_certificates_work_edition_active_idx
  on public.aeternum_certificates(work_id, lower(edition_label))
  where status <> 'revoked';
create index if not exists aeternum_certificates_issuer_idx
  on public.aeternum_certificates(issuer_profile_id, issued_at desc);
create index if not exists aeternum_certificates_owner_idx
  on public.aeternum_certificates(owner_profile_id, issued_at desc);
create index if not exists aeternum_certificates_auction_idx
  on public.aeternum_certificates(auction_id)
  where auction_id is not null;
create index if not exists certificate_events_certificate_idx
  on public.certificate_events(certificate_id, created_at desc);
create index if not exists certificate_events_actor_idx
  on public.certificate_events(actor_id)
  where actor_id is not null;
create index if not exists certificate_events_auction_idx
  on public.certificate_events(auction_id)
  where auction_id is not null;
create index if not exists certificate_events_from_owner_idx
  on public.certificate_events(from_owner_id)
  where from_owner_id is not null;
create index if not exists certificate_events_to_owner_idx
  on public.certificate_events(to_owner_id)
  where to_owner_id is not null;

alter table public.aeternum_certificates enable row level security;
alter table public.certificate_events enable row level security;

drop policy if exists aeternum_certificates_read_managed
  on public.aeternum_certificates;
create policy aeternum_certificates_read_managed
on public.aeternum_certificates for select to authenticated
using (
  issuer_profile_id = (select auth.uid())
  or owner_profile_id = (select auth.uid())
);

drop policy if exists certificate_events_read_managed
  on public.certificate_events;
create policy certificate_events_read_managed
on public.certificate_events for select to authenticated
using (
  exists (
    select 1
    from public.aeternum_certificates c
    where c.id = certificate_id
      and (
        c.issuer_profile_id = (select auth.uid())
        or c.owner_profile_id = (select auth.uid())
      )
  )
);

create or replace function public.verify_aeternum_certificate(
  p_certificate_number text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'certificate_number', c.certificate_number,
    'verification_code', c.verification_code::text,
    'work_id', c.work_id,
    'auction_id', c.auction_id,
    'status', c.status,
    'edition_label', c.edition_label,
    'title_snapshot', c.title_snapshot,
    'artist_snapshot', c.artist_snapshot,
    'year', c.year,
    'discipline', c.discipline,
    'technique', c.technique,
    'dimensions', c.dimensions,
    'owner_public', c.owner_public,
    'owner_label', case
      when c.owner_public then coalesce(
        nullif(btrim(owner_profile.display_name), ''),
        case
          when nullif(btrim(owner_profile.username), '') is null then null
          else '@' || owner_profile.username
        end,
        'Titular verificado'
      )
      else 'Colección privada'
    end,
    'cover_url', work.cover_url,
    'issued_at', c.issued_at,
    'updated_at', c.updated_at,
    'revoked_at', c.revoked_at,
    'events', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'event_type', event.event_type,
          'note', event.note,
          'created_at', event.created_at
        ) order by event.created_at desc
      )
      from public.certificate_events event
      where event.certificate_id = c.id
    ), '[]'::jsonb)
  )
  from public.aeternum_certificates c
  join public.works work on work.id = c.work_id
  left join public.profiles owner_profile on owner_profile.id = c.owner_profile_id
  where upper(c.certificate_number) = upper(btrim(p_certificate_number))
  limit 1;
$$;

create or replace function public.get_work_aeternum_certificate(
  p_work_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_number text;
begin
  select c.certificate_number into v_number
  from public.aeternum_certificates c
  where c.work_id = p_work_id
    and c.status <> 'revoked'
  order by c.issued_at desc
  limit 1;

  if v_number is null then
    return null;
  end if;
  return public.verify_aeternum_certificate(v_number);
end;
$$;

create or replace function public.issue_aeternum_certificate(
  p_work_id uuid,
  p_edition_label text,
  p_owner_public boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_work public.works%rowtype;
  v_artist_name text;
  v_certificate_id uuid;
  v_certificate_number text;
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para emitir un certificado.';
  end if;
  if nullif(btrim(p_edition_label), '') is null
      or char_length(btrim(p_edition_label)) > 80 then
    raise exception 'La edición debe contener entre 1 y 80 caracteres.';
  end if;

  select * into v_work
  from public.works
  where id = p_work_id
  for share;

  if not found then
    raise exception 'La obra no existe.';
  end if;
  if v_work.profile_id <> v_user_id then
    raise exception 'Solo el titular de la obra puede emitir su certificado.';
  end if;
  if not v_work.is_public or v_work.status <> 'published' then
    raise exception 'La obra debe estar publicada para ser certificada.';
  end if;

  select coalesce(
    nullif(btrim(display_name), ''),
    nullif(btrim(username), ''),
    'Artista Corvus'
  ) into v_artist_name
  from public.profiles
  where id = v_user_id;

  v_certificate_number := 'CA-'
    || extract(year from clock_timestamp())::integer
    || '-'
    || lpad(
      nextval('public.aeternum_certificate_number_seq')::text,
      6,
      '0'
    );

  insert into public.aeternum_certificates (
    certificate_number,
    work_id,
    issuer_profile_id,
    owner_profile_id,
    edition_label,
    title_snapshot,
    artist_snapshot,
    year,
    discipline,
    technique,
    dimensions,
    owner_public
  ) values (
    v_certificate_number,
    v_work.id,
    v_user_id,
    v_user_id,
    btrim(p_edition_label),
    v_work.title,
    v_artist_name,
    v_work.year,
    v_work.discipline,
    coalesce(v_work.technique, ''),
    coalesce(v_work.dimensions, ''),
    coalesce(p_owner_public, false)
  ) returning id into v_certificate_id;

  insert into public.certificate_events (
    certificate_id,
    event_type,
    actor_id,
    to_owner_id,
    note
  ) values (
    v_certificate_id,
    'issued',
    v_user_id,
    v_user_id,
    'Certificado emitido por el titular de la obra.'
  );

  return v_certificate_number;
exception
  when unique_violation then
    raise exception 'Ya existe un certificado activo para esta obra y edición.';
end;
$$;

create or replace function public.set_certificate_owner_public(
  p_certificate_id uuid,
  p_owner_public boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para cambiar la privacidad.';
  end if;

  update public.aeternum_certificates
  set owner_public = coalesce(p_owner_public, false),
      updated_at = clock_timestamp()
  where id = p_certificate_id
    and owner_profile_id = v_user_id
    and status <> 'revoked';

  if not found then
    raise exception 'No tienes permiso para modificar este certificado.';
  end if;

  insert into public.certificate_events (
    certificate_id, event_type, actor_id, note
  ) values (
    p_certificate_id,
    'privacy_changed',
    v_user_id,
    case
      when p_owner_public then 'El titular hizo pública su identidad.'
      else 'El titular ocultó su identidad pública.'
    end
  );
end;
$$;

create or replace function public.revoke_aeternum_certificate(
  p_certificate_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión para revocar un certificado.';
  end if;
  if nullif(btrim(p_reason), '') is null then
    raise exception 'Debes indicar el motivo de la revocación.';
  end if;

  update public.aeternum_certificates
  set status = 'revoked',
      revoked_at = clock_timestamp(),
      updated_at = clock_timestamp()
  where id = p_certificate_id
    and issuer_profile_id = v_user_id
    and status <> 'revoked';

  if not found then
    raise exception 'No tienes permiso para revocar este certificado.';
  end if;

  insert into public.certificate_events (
    certificate_id, event_type, actor_id, note
  ) values (
    p_certificate_id, 'revoked', v_user_id, btrim(p_reason)
  );
end;
$$;

create or replace function public.validate_auction_certificate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_certificate_number text;
begin
  if nullif(btrim(new.certificate_id), '') is null then
    new.certificate_id := '';
    return new;
  end if;

  select c.certificate_number into v_certificate_number
  from public.aeternum_certificates c
  where upper(c.certificate_number) = upper(btrim(new.certificate_id))
    and c.work_id = new.work_id
    and c.owner_profile_id = new.seller_profile_id
    and c.status <> 'revoked'
  for share;

  if not found then
    raise exception 'El certificado no es válido para esta obra o vendedor.';
  end if;

  new.certificate_id := v_certificate_number;
  return new;
end;
$$;

create or replace function public.transfer_certificate_on_auction_close()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_certificate public.aeternum_certificates%rowtype;
begin
  if new.status <> 'ended'
      or old.status = 'ended'
      or new.winner_id is null
      or nullif(btrim(new.certificate_id), '') is null then
    return new;
  end if;

  select * into v_certificate
  from public.aeternum_certificates c
  where upper(c.certificate_number) = upper(btrim(new.certificate_id))
    and c.work_id = new.work_id
    and c.owner_profile_id = new.seller_profile_id
    and c.status <> 'revoked'
  for update;

  if not found then
    return new;
  end if;

  update public.aeternum_certificates
  set owner_profile_id = new.winner_id,
      auction_id = new.id,
      status = 'transferred',
      updated_at = clock_timestamp()
  where id = v_certificate.id;

  insert into public.certificate_events (
    certificate_id,
    event_type,
    actor_id,
    from_owner_id,
    to_owner_id,
    auction_id,
    note
  ) values (
    v_certificate.id,
    'auction_awarded',
    new.seller_profile_id,
    v_certificate.owner_profile_id,
    new.winner_id,
    new.id,
    'Titularidad transferida por adjudicación en subasta.'
  );

  return new;
end;
$$;

drop trigger if exists auctions_validate_certificate on public.auctions;
create trigger auctions_validate_certificate
before insert or update of certificate_id, work_id, seller_profile_id
on public.auctions
for each row execute function public.validate_auction_certificate();

drop trigger if exists auctions_transfer_certificate on public.auctions;
create trigger auctions_transfer_certificate
after update of status, winner_id on public.auctions
for each row execute function public.transfer_certificate_on_auction_close();

revoke all privileges on table public.aeternum_certificates
  from public, anon, authenticated;
revoke all privileges on table public.certificate_events
  from public, anon, authenticated;

grant select on table public.aeternum_certificates to authenticated;
grant select on table public.certificate_events to authenticated;
grant all privileges on table public.aeternum_certificates to service_role;
grant all privileges on table public.certificate_events to service_role;

revoke execute on function public.verify_aeternum_certificate(text)
  from public;
revoke execute on function public.get_work_aeternum_certificate(uuid)
  from public, anon;
revoke execute on function public.issue_aeternum_certificate(uuid, text, boolean)
  from public, anon;
revoke execute on function public.set_certificate_owner_public(uuid, boolean)
  from public, anon;
revoke execute on function public.revoke_aeternum_certificate(uuid, text)
  from public, anon;
revoke execute on function public.validate_auction_certificate()
  from public, anon, authenticated;
revoke execute on function public.transfer_certificate_on_auction_close()
  from public, anon, authenticated;

grant execute on function public.verify_aeternum_certificate(text)
  to anon, authenticated;
grant execute on function public.get_work_aeternum_certificate(uuid)
  to authenticated;
grant execute on function public.issue_aeternum_certificate(uuid, text, boolean)
  to authenticated;
grant execute on function public.set_certificate_owner_public(uuid, boolean)
  to authenticated;
grant execute on function public.revoke_aeternum_certificate(uuid, text)
  to authenticated;
