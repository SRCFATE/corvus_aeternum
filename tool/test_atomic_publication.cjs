// In-memory PostgreSQL integration test. Never connects to a real database.
const { PGlite } = require(process.env.CORVUS_PGLITE || '@electric-sql/pglite');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
(async () => {
  const db = new PGlite();
  await db.exec(`create role authenticated; create role anon; create schema auth;
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
    create table profiles(id uuid primary key); insert into profiles values('${id(1)}'),('${id(2)}');`);
  await db.exec(fs.readFileSync(path.join(root,'docs/atelier_schema.sql'),'utf8').replace('create extension if not exists pgcrypto;',''));
  const history = fs.readFileSync(path.join(root,'supabase/migrations/20260905053554_atelier_professional_features.sql'),'utf8');
  await db.exec(history.slice(history.indexOf('alter table public.atelier_versions'),history.indexOf('-- Un punto de restauración')));
  await db.exec(`create table works(id uuid primary key default gen_random_uuid(), profile_id uuid not null references profiles(id), title text,
    description text, discipline text, subdiscipline text, medium text, work_type text, status text, is_public boolean,
    is_complete boolean, is_for_sale boolean, is_mature boolean, year smallint, tags text[], text_body text, language text,
    aeternum_ficha jsonb, atelier_project_id uuid, universe text, aeternum_status text, updated_at timestamptz default now());
    alter table works enable row level security;
    create policy own_work on works to authenticated using(profile_id = auth.uid()) with check(profile_id = auth.uid());
    grant usage on schema public, auth to authenticated, anon; grant select, insert, update on all tables in schema public to authenticated;
    create function fail_test_snapshot() returns trigger language plpgsql as $$begin
      if current_setting('test.fail_history',true) = 'yes' then raise exception 'History unavailable'; end if; return new; end$$;
    create trigger fail_test_snapshot before insert on atelier_versions for each row execute function fail_test_snapshot();`);
  await db.exec(fs.readFileSync(path.join(root,'supabase/migrations/20260921190821_atelier_atomic_publication.sql'),'utf8'));
  await db.exec(`set role authenticated; set test.uid = '${id(1)}';
    insert into atelier_projects(id,profile_id,title) values('${id(3)}','${id(1)}','Libro');
    insert into atelier_nodes(id,project_id,profile_id,kind,title,body) values('${id(4)}','${id(3)}','${id(1)}','chapter','Entrada','Primera edición');`);
  const state = async () => ({project:(await db.query('select * from atelier_projects')).rows[0], node:(await db.query('select * from atelier_nodes')).rows[0]});
  const input = async (text, preparing = false) => {
    const {project,node} = await state();
    return [project.id, project.updated_at, JSON.stringify([{id:node.id,updated_at:node.updated_at}]),
      JSON.stringify([{id:node.id,title:node.title,body:node.body}]), JSON.stringify({text_body:text, aeternum_ficha:{}, discipline:'Literatura',work_type:'text',tags:['ficción']}),preparing];
  };
  const commit = args => db.query('select atelier_commit_publication($1::uuid,$2::timestamptz,$3::jsonb,$4::jsonb,$5::jsonb,$6::boolean) as result',args);
  const first = await input('Primera edición',true);
  const result = (await commit(first)).rows[0].result;
  let works = (await db.query('select * from works')).rows;
  assert.equal(works.length,1); assert.equal(works[0].is_public,false); assert.equal(works[0].status,'draft');
  await commit(first);
  assert.equal((await db.query('select count(*)::int as n from atelier_versions')).rows[0].n,1,'lost-response retry does not add history');
  const stale = await input('Texto obsoleto');
  await db.exec("update atelier_nodes set body='Segunda edición',updated_at=now();");
  await assert.rejects(commit(stale), /EDITION_CHANGED/);
  assert.equal((await db.query('select text_body from works')).rows[0].text_body,'Primera edición');
  await db.exec("update works set status='published',is_public=true;");
  const accepted = await input('Segunda edición');
  await commit(accepted);
  works = (await db.query('select * from works')).rows;
  assert.equal(works[0].id,result.work_id); assert.equal(works[0].status,'published'); assert.equal(works[0].is_public,true);
  const snapshot = (await db.query('select snapshot from atelier_versions order by created_at desc limit 1')).rows[0].snapshot;
  assert.equal(snapshot.nodes[0].body,'Segunda edición');
  assert.equal(snapshot.project.metadata.publication_snapshot[0].body,'Segunda edición');
  const projectBefore = (await state()).project;
  const failed = await input('No debe guardarse');
  await db.exec("set test.fail_history = 'yes';");
  await assert.rejects(commit(failed), /History unavailable/);
  assert.equal((await db.query('select text_body from works')).rows[0].text_body,'Segunda edición');
  assert.deepEqual((await state()).project.metadata,projectBefore.metadata,'failed history rolls back publication metadata');
  await db.exec("set test.fail_history = 'no';");
  const privacy = await input('Privado');
  privacy[4] = JSON.stringify({text_body:'Privado', aeternum_ficha:{public_references:[{id:id(4),title:'Entrada',body:'Segunda edición'}]}});
  await assert.rejects(commit(privacy),/Private reference/);
  const prepareAgain = await input('No retirar una obra pública',true);
  await commit(prepareAgain);
  assert.equal((await db.query('select text_body from works')).rows[0].text_body,'Segunda edición');
  await db.exec(`set test.uid = '${id(2)}';`);
  await assert.rejects(commit(accepted),/Only the owner/);
  await db.exec('set role anon;'); await assert.rejects(commit(accepted),/permission denied/);
  await db.close();
  console.log('Atomic publication: rollback, stale review, private references, idempotency, status preservation and ownership passed.');
})().catch(error => {console.error(error); process.exitCode=1;});
