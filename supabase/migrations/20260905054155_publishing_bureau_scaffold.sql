-- Corvus Publishing Bureau — cimiento, no implementación.
--
-- Los servicios editoriales (evaluación, corrección, maquetación, portada,
-- ISBN, producción) NO forman parte de ningún plan: se cotizan y se pagan
-- aparte. Por eso viven en sus propias tablas y su propio flujo de cobro, y
-- por eso enviar un manuscrito está disponible también en Free.
--
-- Aquí queda el modelo de datos y su seguridad. El flujo editorial completo
-- —asignación de lectores, dictamen, versiones corregidas— se construirá sobre
-- esto sin volver a tocar el esquema base.

create table if not exists public.manuscript_submissions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.atelier_projects(id) on delete set null,
  work_id uuid references public.works(id) on delete set null,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  workspace_id uuid references public.atelier_workspaces(id) on delete set null,
  title text not null,
  synopsis text not null default '',
  genre text not null default '',
  language text not null default 'es',
  word_count integer not null default 0,
  services_requested text[] not null default '{}'::text[],
  manuscript_snapshot jsonb,
  status text not null default 'draft' check (status in (
    'draft', 'submitted', 'in_review', 'quoted', 'accepted', 'declined', 'withdrawn'
  )),
  reviewer_notes text not null default '',
  submitted_at timestamptz,
  decided_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists manuscript_submissions_profile_idx
  on public.manuscript_submissions (profile_id, status, created_at desc);

create table if not exists public.editorial_quotes (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null
    references public.manuscript_submissions(id) on delete cascade,
  service_key text not null,
  description text not null default '',
  currency text not null default 'MXN',
  amount integer not null default 0 check (amount >= 0),
  estimated_days smallint,
  status text not null default 'draft'
    check (status in ('draft', 'sent', 'accepted', 'declined', 'expired')),
  valid_until timestamptz,
  issued_by uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists editorial_quotes_submission_idx
  on public.editorial_quotes (submission_id, status);

create table if not exists public.publishing_service_orders (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid references public.manuscript_submissions(id) on delete set null,
  quote_id uuid references public.editorial_quotes(id) on delete set null,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  workspace_id uuid references public.atelier_workspaces(id) on delete set null,
  service_key text not null,
  status text not null default 'pending' check (status in (
    'pending', 'paid', 'in_progress', 'delivered', 'canceled', 'refunded'
  )),
  currency text not null default 'MXN',
  amount integer not null default 0 check (amount >= 0),
  transaction_id uuid references public.billing_transactions(id) on delete set null,
  assigned_to uuid references public.profiles(id) on delete set null,
  deliverables jsonb not null default '[]'::jsonb,
  due_at timestamptz,
  delivered_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists publishing_service_orders_profile_idx
  on public.publishing_service_orders (profile_id, status, created_at desc);

-- Enviar exige el derecho —que Free también tiene— y ser dueño del proyecto.
-- El envío congela una copia del manuscrito para que la evaluación no se mueva
-- bajo los pies del lector mientras el autor sigue escribiendo.
create or replace function public.submit_manuscript(
  p_project_id uuid,
  p_services text[] default '{}'::text[],
  p_synopsis text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  p record;
  v_id uuid;
  v_words integer := 0;
  v_snapshot jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHENTICATED');
  end if;

  select * into p from public.atelier_projects where id = p_project_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_PROJECT_NOT_FOUND');
  end if;

  if p.profile_id <> v_uid then
    return jsonb_build_object('ok', false, 'reason_code', 'NOT_AUTHORIZED');
  end if;

  if not public.has_entitlement(v_uid, 'atelier.publishing.submissions', p.workspace_id) then
    return jsonb_build_object('ok', false, 'reason_code', 'ATELIER_SUBMISSIONS_NOT_INCLUDED');
  end if;

  if exists (
    select 1 from public.manuscript_submissions s
    where s.project_id = p_project_id
      and s.status in ('submitted', 'in_review', 'quoted')
  ) then
    return jsonb_build_object('ok', false, 'reason_code', 'BUREAU_SUBMISSION_IN_PROGRESS');
  end if;

  select
    coalesce(sum(array_length(
      regexp_split_to_array(trim(coalesce(n.body, '')), '\s+'), 1
    )), 0),
    coalesce(jsonb_agg(jsonb_build_object(
      'kind', n.kind, 'title', n.title, 'body', n.body, 'position', n.position
    ) order by n.position), '[]'::jsonb)
  into v_words, v_snapshot
  from public.atelier_nodes n
  where n.project_id = p_project_id and trim(coalesce(n.body, '')) <> '';

  insert into public.manuscript_submissions (
    project_id, profile_id, workspace_id, title, synopsis, genre, language,
    word_count, services_requested, manuscript_snapshot, status, submitted_at
  ) values (
    p_project_id, v_uid, p.workspace_id, p.title,
    coalesce(nullif(trim(p_synopsis), ''), p.metadata->>'description', ''),
    p.genre, p.language, v_words, coalesce(p_services, '{}'::text[]),
    v_snapshot, 'submitted', now()
  )
  returning id into v_id;

  insert into public.atelier_editorial_profiles (project_id, bureau_status)
  values (p_project_id, 'submitted')
  on conflict (project_id) do update set
    bureau_status = 'submitted', updated_at = now();

  perform public.atelier_log(
    p.workspace_id, p_project_id, 'bureau.submit', 'manuscript_submission',
    v_id::text, jsonb_build_object('word_count', v_words)
  );

  return jsonb_build_object('ok', true, 'submission_id', v_id, 'word_count', v_words);
end;
$fn$;

alter table public.manuscript_submissions enable row level security;
alter table public.editorial_quotes enable row level security;
alter table public.publishing_service_orders enable row level security;

drop policy if exists "manuscript_submissions_select_own" on public.manuscript_submissions;
create policy "manuscript_submissions_select_own" on public.manuscript_submissions
  for select to authenticated
  using (profile_id = (select auth.uid()) or public.is_admin());

drop policy if exists "editorial_quotes_select_own" on public.editorial_quotes;
create policy "editorial_quotes_select_own" on public.editorial_quotes
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.manuscript_submissions s
      where s.id = submission_id and s.profile_id = (select auth.uid())
    )
  );

drop policy if exists "publishing_service_orders_select_own"
  on public.publishing_service_orders;
create policy "publishing_service_orders_select_own"
  on public.publishing_service_orders
  for select to authenticated
  using (profile_id = (select auth.uid()) or public.is_admin());

do $mig$
declare
  t text;
begin
  foreach t in array array[
    'manuscript_submissions', 'editorial_quotes', 'publishing_service_orders'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $mig$;

grant select on public.manuscript_submissions to authenticated;
grant select on public.editorial_quotes to authenticated;
grant select on public.publishing_service_orders to authenticated;

revoke all on function public.submit_manuscript(uuid, text[], text) from public;
grant execute on function public.submit_manuscript(uuid, text[], text) to authenticated;
