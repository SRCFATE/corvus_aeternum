// Run with CORVUS_PGLITE pointing at an installed @electric-sql/pglite package.
// Uses an in-memory PostgreSQL instance; never connects to Supabase.
const { PGlite } = require(process.env.CORVUS_PGLITE || '@electric-sql/pglite');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;

(async () => {
  const db = new PGlite();
  await db.exec(`create role authenticated; create role anon; create schema auth;
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid', true), '')::uuid$$;
    create table public.profiles(id uuid primary key);
    insert into public.profiles values ('${id(1)}'), ('${id(2)}');`);
  const schema = fs.readFileSync(path.join(root, 'docs/atelier_schema.sql'), 'utf8').replace('create extension if not exists pgcrypto;', '');
  await db.exec(schema);
  const history = fs.readFileSync(path.join(root, 'supabase/migrations/20260905053554_atelier_professional_features.sql'), 'utf8');
  await db.exec(history.slice(history.indexOf('alter table public.atelier_versions'), history.indexOf('-- Un punto de restauración')));
  await db.exec(`grant usage on schema public, auth to authenticated, anon;
    grant select, insert, update on all tables in schema public to authenticated;
    grant execute on function auth.uid() to authenticated, anon;`);
  await db.exec(fs.readFileSync(path.join(root, 'supabase/migrations/20260921184641_atelier_private_project_import.sql'), 'utf8'));
  await db.exec(`set role authenticated; set test.uid = '${id(1)}';`);
  const node = {id:id(10), kind:'chapter', title:'Capítulo', body:`[Ana](corvus-node:${id(11)})`, status:'done', visibility:'public', tags:['luna'], metadata:{rich_text_delta:[{insert:'Ana', attributes:{link:`corvus-node:${id(11)}`}}]}, position:3};
  const payload = {project:{id:id(9), title:'Copia', type:'Novela', metadata:{publication_work_id:id(88), publication_snapshot:[], deleted_at:'2020-01-01', synopsis_short:'Conservar'}},
    nodes:[node, {...node, id:id(11), kind:'character', title:'Ana'}],
    relations:[{id:id(12), source_node_id:id(10), target_node_id:id(11), relation_type:'mentions'}],
    versions:[{label:'Antes', created_at:'2025-01-01T00:00:00Z', author_name:'Autora original', metadata:{snapshot_nodes:[node], snapshot_project:{id:id(9),title:'Antiguo',metadata:{synopsis_short:'Historia',publication_work_id:id(88)}}}}]};
  const run = (data, request) => db.query('select public.atelier_import_project($1::jsonb, $2::uuid) as id', [JSON.stringify(data), request]);
  const copy = id(20);
  assert.equal((await run(payload, copy)).rows[0].id, copy);
  assert.equal((await run(payload, copy)).rows[0].id, copy, 'same request is idempotent');
  const p = (await db.query('select * from atelier_projects')).rows[0];
  assert.equal(p.visibility, 'private'); assert.equal(p.profile_id, id(1));
  assert.equal(p.metadata.publication_work_id, undefined); assert.equal(p.metadata.deleted_at, undefined);
  assert.equal(p.metadata.synopsis_short, 'Conservar');
  const nodes = (await db.query('select * from atelier_nodes order by kind')).rows;
  assert.equal(nodes.length, 2); assert(nodes.every(n => n.visibility === 'private' && n.profile_id === id(1)));
  const chapter = nodes.find(n => n.kind === 'chapter'), character = nodes.find(n => n.kind === 'character');
  assert.notEqual(chapter.id, id(10)); assert.equal(chapter.position, 3);
  assert.equal(chapter.body, `[Ana](corvus-node:${character.id})`);
  assert.equal(chapter.metadata.rich_text_delta[0].attributes.link, `corvus-node:${character.id}`);
  const relation = (await db.query('select * from atelier_relations')).rows[0];
  assert.equal(relation.source_node_id, chapter.id); assert.equal(relation.target_node_id, character.id);
  const version = (await db.query('select * from atelier_versions')).rows[0];
  assert.equal(version.snapshot.nodes[0].id, chapter.id); assert.equal(version.kind, 'import');
  assert.equal(version.snapshot.project.metadata.synopsis_short, 'Historia');
  assert.equal(version.snapshot.project.metadata.publication_work_id, undefined);
  assert.equal(version.metadata.imported_author_name, 'Autora original');
  // Invalid content encountered AFTER project insertion must roll everything back.
  const malformed = structuredClone(payload); malformed.nodes[1].position = 'invalid';
  await assert.rejects(run(malformed, id(21)));
  assert.equal((await db.query('select count(*)::int as n from atelier_projects')).rows[0].n, 1);
  const missing = structuredClone(payload); missing.relations[0].target_node_id = id(99);
  await assert.rejects(run(missing, id(22)));
  const duplicate = structuredClone(payload); duplicate.nodes.push(node);
  await assert.rejects(run(duplicate, id(23)));
  await assert.rejects(run({...payload, project:{...payload.project, title:'Changed'}}, copy));
  await db.exec(`set test.uid = '${id(2)}';`);
  assert.equal((await db.query('select count(*)::int as n from atelier_projects')).rows[0].n, 0, 'other account cannot read copy');
  await assert.rejects(run(payload, copy), 'other account cannot claim the same request');
  await run(payload, id(24));
  assert.equal((await db.query('select profile_id from atelier_projects')).rows[0].profile_id, id(2));
  await db.exec("set test.uid = ''; ");
  await assert.rejects(run(payload, id(25)), 'missing identity rejected');
  await db.exec('set role anon;');
  await assert.rejects(run(payload, id(26)), 'anonymous role has no execute grant');
  await db.close();
  console.log('Project import: remapping, privacy, history, rollback, idempotency and account isolation passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
