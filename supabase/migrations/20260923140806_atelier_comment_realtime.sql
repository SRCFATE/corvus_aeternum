-- Postgres Changes applies existing SELECT policies to every subscriber.
-- Do not change comment visibility or introduce broadcast privileges.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'atelier_comments'
  ) then
    alter publication supabase_realtime add table public.atelier_comments;
  end if;
end
$$;
