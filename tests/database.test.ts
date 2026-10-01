import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const a='00000000-0000-4000-8000-000000000001',b='00000000-0000-4000-8000-000000000002';
test('migration réelle: Auth, RLS, campagnes, idempotence et présidentielle',async()=>{
 const db=new PGlite();
 try{
 await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key,raw_user_meta_data jsonb);create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;grant usage on schema public,auth to anon,authenticated;grant execute on function auth.uid() to anon,authenticated;`);
 await db.exec(await readFile('supabase/migrations/001_game.sql','utf8'));
 await db.exec(`insert into auth.users values('${a}','{"username":"Alice"}'),('${b}','{"username":"Bob"}');set role authenticated;select set_config('request.jwt.claim.sub','${a}',false);`);
 const snap=await db.query<any>('select public.game_snapshot() as data');assert.equal(snap.rows[0].data.state.player.username,'Alice');assert.equal(snap.rows[0].data.state.territories.length,101);assert.equal(snap.rows[0].data.admin,false);
 assert.equal((await db.query('select * from public.player_resources')).rows.length,1);
 await assert.rejects(db.exec('update public.player_resources set energy=1000'));
 await assert.rejects(db.exec('update public.profiles set xp=99999'));
 await assert.rejects(db.exec(`insert into public.game_admins values('${a}')`));
 await assert.rejects(db.exec('select public.admin_end_season()'));
 await assert.rejects(db.exec("select public.play_campaign('33','meeting',-500,null,'10000000-0000-4000-8000-000000000001')"));
 await db.exec("select public.join_faction('canopy')");
 const call="select public.play_campaign('33','meeting',30,'grand-meeting','10000000-0000-4000-8000-000000000002') as response";
 const first=await db.query<any>(call);const replay=await db.query<any>(call);assert.deepEqual(first.rows,replay.rows);
 const after=await db.query<any>('select public.game_snapshot() as data');assert.equal(after.rows[0].data.state.player.energy,85);assert.equal(after.rows[0].data.state.player.cards['grand-meeting'],2);assert.equal(after.rows[0].data.state.player.campaigns,1);
 await assert.rejects(db.exec("select public.play_campaign('33','door',10,null,'10000000-0000-4000-8000-000000000003')"));
 await assert.rejects(db.exec("select public.join_faction('atlas')"));
 await assert.rejects(db.exec("select public.claim_mission('campaigns')"));
 await assert.rejects(db.exec("select public.claim_mission(null)"));
 for(let i=4;i<=5;i++){await db.exec(`reset role;update public.player_resources set last_action_at=now()-interval '31 seconds' where user_id='${a}';set role authenticated;select public.play_campaign('33','door',10,null,'10000000-0000-4000-8000-00000000000${i}')`)}
 await db.exec("select public.claim_mission('campaigns')");await assert.rejects(db.exec("select public.claim_mission('campaigns')"));
 const mission=await db.query<any>('select public.game_snapshot() as data');assert.equal(mission.rows[0].data.state.player.cards['grand-meeting'],3);
 await db.exec(`select set_config('request.jwt.claim.sub','${b}',false)`);
 assert.equal((await db.query<any>('select user_id from public.campaigns')).rows.length,0);
 await db.exec(`reset role;insert into public.game_admins values('${a}');update public.seasons set ends_at=now()-interval '3 days',starts_at=now()-interval '33 days';set role authenticated;select set_config('request.jwt.claim.sub','${a}',false);select public.advance_season();`);
 const firstTour=await db.query<any>('select phase from public.seasons');assert.equal(firstTour.rows[0].phase,'runoff');
 await db.exec('select public.advance_season();select public.advance_season()');
 const last=await db.query<any>('select public.game_snapshot() as data');assert.equal(last.rows[0].data.state.season.phase,'finished');assert.equal(last.rows[0].data.state.season.results.length,2);assert(Math.abs(last.rows[0].data.state.season.results.reduce((s:number,r:any)=>s+r.score,0)-100)<1e-6);
 await db.exec('select public.admin_start_season()');assert.equal((await db.query<any>("select count(*)::int as n from public.seasons where phase='expansion'")).rows[0].n,1);
 await db.exec('set role anon');await assert.rejects(db.exec('select public.game_snapshot()'));
 }finally{await db.close()}
});
