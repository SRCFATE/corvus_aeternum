// In-memory PostgreSQL; no connection to production or changes to real works.
const { PGlite } = require(process.env.CORVUS_PGLITE || '@electric-sql/pglite');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
(async () => {
  const db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
    create function public.is_admin() returns boolean language sql stable as $$select auth.uid() = '${id(1)}'::uuid$$;
    grant usage on schema public, auth to anon, authenticated;
    create table works(id uuid primary key, profile_id uuid, discipline text,
      is_public boolean, status text, likes_count int, views_count int,
      published_at timestamptz, created_at timestamptz default now());
    alter table works enable row level security;
    create policy public_works on works for select using ((is_public and status='published') or profile_id=auth.uid());
    grant select on works to anon, authenticated;
    create table work_views(work_id uuid references works, viewed_at timestamptz,
      viewer_id uuid, fingerprint text);
    alter table work_views enable row level security;
    create index work_views_dedup_idx on work_views(work_id,viewed_at desc);
    insert into works(id,profile_id,discipline,is_public,status,likes_count,views_count,published_at) values
      ('${id(10)}','${id(2)}','Literatura',true,'published',50,1000,now()-interval '30 days'),
      ('${id(11)}','${id(2)}','Literatura',true,'published',5,200,now()-interval '2 days'),
      ('${id(12)}','${id(2)}','Pintura',true,'published',10,400,now()-interval '1 day'),
      ('${id(13)}','${id(2)}','Literatura',false,'published',999,9999,now()),
      ('${id(14)}','${id(2)}','Literatura',true,'draft',999,9999,now()),
      ('${id(15)}','${id(2)}','Literatura',true,'published',1,1,now()-interval '3 days');
    insert into work_views select '${id(10)}',now()-interval '10 days',null,'never exposed' from generate_series(1,10);
    insert into work_views select '${id(10)}',now()-interval '1 day',null,'never exposed' from generate_series(1,4);
    insert into work_views select '${id(11)}',now()-interval '10 days',null,'never exposed' from generate_series(1,2);
    insert into work_views select '${id(11)}',now()-interval '1 day',null,'never exposed' from generate_series(1,6);
    insert into work_views select '${id(12)}',now()-interval '1 day',null,'never exposed' from generate_series(1,5);
    insert into work_views select '${id(13)}',now()-interval '1 day',null,'never exposed' from generate_series(1,100);
    insert into work_views select '${id(15)}',now()-interval '1 day',null,'never exposed' from generate_series(1,2);
    insert into work_views values('${id(11)}',now()+interval '1 day',null,'future excluded'),
      ('${id(11)}',now()-interval '15 days',null,'old excluded');`);
  await db.exec(fs.readFileSync(path.join(__dirname,'../supabase/migrations/20260923141554_public_work_rankings.sql'),'utf8'));
  const rank = async (mode, discipline = null, limit = 40) =>
    (await db.query('select * from public_work_rankings($1,$2,$3)', [mode, discipline, limit])).rows;
  await db.exec(`set role authenticated; set test.uid='${id(1)}';
    insert into editorial_work_selections(work_id,reason) values('${id(11)}','Un motivo editorial visible'),('${id(13)}','Esta elección ahora es privada');`);
  await db.exec(`set test.uid='${id(2)}';`);
  await assert.rejects(db.query('insert into editorial_work_selections(work_id,reason) values($1,$2)', [id(10),'No tengo permiso editorial']), /row-level security/);
  assert.equal((await rank('editorial')).length, 1, 'even owners never rank private works');
  await db.exec('set role anon; set test.uid = \'\';');
  assert.deepEqual((await rank('popular')).map(r => r.work_id), [id(10),id(12),id(11),id(15)]);
  assert.deepEqual((await rank('active')).map(r => r.work_id), [id(12),id(11),id(15),id(10)]);
  const trends = await rank('trending');
  assert.deepEqual(trends.map(r => r.work_id), [id(12),id(11)]);
  assert.equal(Number(trends[1].recent_views),6);
  assert.equal(Number(trends[1].previous_views),2);
  assert.deepEqual((await rank('trending','Literatura')).map(r=>r.work_id), [id(11)]);
  assert.equal((await rank('popular',null,1)).length,1);
  assert.equal((await rank('editorial'))[0].editorial_reason,'Un motivo editorial visible');
  assert.equal((await db.query('select * from editorial_work_selections')).rows.length,1);
  await assert.rejects(db.query('select * from work_views'),/permission denied/);
  await assert.rejects(rank('invalid'), /Unknown ranking mode/);
  assert(!JSON.stringify(trends).includes('fingerprint'));
  await db.close();
  console.log('PASS: ranking periods, growth, minimum activity, curation permissions, privacy, filters and limits');
})().catch(error => { console.error(error); process.exitCode = 1; });
