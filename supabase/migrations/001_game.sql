-- C’EST À QUI 2027 ? — PostgreSQL / Supabase Free, MVP.
-- Run once in a NEW dedicated Supabase project. No service-role key in the browser.
begin;
create table public.game_admins(user_id uuid primary key references auth.users(id) on delete cascade);
create table public.game_config(id boolean primary key default true check(id),value jsonb not null,version integer not null default 1);
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,username text not null check(char_length(username) between 2 and 24),avatar text not null default 'initials' check(avatar in ('initials','sun','leaf','shield','star')),xp integer not null default 0 check(xp>=0),campaigns integer not null default 0,defenses integer not null default 0,banned boolean not null default false,created_at timestamptz not null default now());
create table public.factions(id text primary key,name text not null,color text not null,motto text not null);
create table public.faction_members(user_id uuid primary key references public.profiles on delete cascade,faction_id text not null references public.factions,role text not null default 'member' check(role in ('member','admin')));
create table public.regions(id text primary key,name text not null unique);
create table public.departments(code text primary key,name text not null,region_id text not null references public.regions,defense integer not null default 30 check(defense between 0 and 100),mobilization integer not null default 20,bonus text not null default 'Mobilisation locale');
create table public.seasons(id uuid primary key default gen_random_uuid(),name text not null,starts_at timestamptz not null default now(),ends_at timestamptz not null default now()+interval '30 days',phase text not null default 'expansion' check(phase in ('expansion','runoff','finished')),winner text references public.factions,check(ends_at>starts_at));
create unique index one_open_season on public.seasons((true)) where phase<>'finished';
create table public.territory_influence(season_id uuid not null references public.seasons,department_code text not null references public.departments,faction_id text not null references public.factions,points integer not null check(points>=0),primary key(season_id,department_code,faction_id));
create table public.player_resources(user_id uuid primary key references public.profiles on delete cascade,energy integer not null default 100 check(energy between 0 and 100),budget integer not null default 1600 check(budget between 0 and 10000),militants integer not null default 120 check(militants between 0 and 500),influence integer not null default 250 check(influence>=0),militant_carry integer not null default 0 check(militant_carry between 0 and 9),updated_at timestamptz not null default now(),last_action_at timestamptz,mission_day date,daily_campaigns integer not null default 0,daily_defenses integer not null default 0,claimed jsonb not null default '[]'::jsonb);
create table public.cards(id text primary key,name text not null,kind text not null check(kind in ('campaign','defense')),rarity text not null);
create table public.player_cards(user_id uuid not null references public.profiles on delete cascade,card_id text not null references public.cards,quantity integer not null default 0 check(quantity between 0 and 20),primary key(user_id,card_id));
create table public.campaigns(id uuid primary key default gen_random_uuid(),request_id uuid not null,user_id uuid not null references public.profiles on delete cascade,season_id uuid not null references public.seasons,department_code text not null references public.departments,action text not null,investment integer not null,gain integer not null,response jsonb not null,created_at timestamptz not null default now(),unique(user_id,request_id));
create index campaigns_user_date on public.campaigns(user_id,created_at desc);
create table public.battles(id uuid primary key references public.campaigns on delete cascade,season_id uuid not null references public.seasons,department_code text not null references public.departments,faction_id text not null references public.factions,gain integer not null,defensive boolean not null,created_at timestamptz not null default now());
create table public.game_events(id uuid primary key default gen_random_uuid(),season_id uuid not null references public.seasons,message text not null,created_at timestamptz not null default now());
create index events_recent on public.game_events(created_at desc);
create table public.season_rankings(season_id uuid not null references public.seasons,faction_id text not null references public.factions,round integer not null check(round in (1,2)),score numeric not null check(score>=0),primary key(season_id,faction_id,round));
create table public.season_supports(season_id uuid not null references public.seasons,user_id uuid not null references public.profiles on delete cascade,finalist text not null references public.factions,primary key(season_id,user_id));

create function public.is_game_admin() returns boolean language sql stable security definer set search_path=public,pg_temp as $$select exists(select 1 from public.game_admins where user_id=auth.uid())$$;
create function public.create_game_profile() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 insert into public.profiles(id,username) values(new.id,left(coalesce(nullif(new.raw_user_meta_data->>'username',''),'Stratège'),24));
 insert into public.faction_members(user_id,faction_id) values(new.id,'horizon');
 insert into public.player_resources(user_id) values(new.id);
 insert into public.player_cards(user_id,card_id,quantity) values(new.id,'grand-meeting',3),(new.id,'bastion',2);
 return new;
end;$$;
create trigger on_game_signup after insert on auth.users for each row execute function public.create_game_profile();

-- No client write grants to game-owned state. RLS is enabled even for read-only tables.
do $$declare t text;begin
 foreach t in array array['game_admins','game_config','profiles','factions','faction_members','regions','departments','seasons','territory_influence','player_resources','cards','player_cards','campaigns','battles','game_events','season_rankings','season_supports'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 end loop;
 foreach t in array array['game_config','profiles','factions','regions','departments','seasons','territory_influence','cards','game_events','season_rankings'] loop
 execute format('grant select on public.%I to anon, authenticated',t);
 execute format('create policy public_read on public.%I for select using (true)',t);
 end loop;
 foreach t in array array['faction_members','player_resources','player_cards','campaigns','season_supports'] loop
 execute format('grant select on public.%I to authenticated',t);
 execute format('create policy own_read on public.%I for select to authenticated using (user_id=auth.uid())',t);
 end loop;
end$$;
-- Public profile fields contain no email or private account attributes.
grant update(username,avatar) on public.profiles to authenticated;
create policy own_profile_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

create function public.join_faction(p_faction text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();begin
 if uid is null then raise exception 'Connexion requise';end if;
 perform 1 from public.player_resources where user_id=uid for update;
 if exists(select 1 from public.profiles where id=uid and banned) then raise exception 'Compte suspendu';end if;
 if exists(select 1 from public.campaigns c join public.seasons s on s.id=c.season_id where c.user_id=uid and s.phase<>'finished') then raise exception 'Votre faction reste la même pendant la saison';end if;
 if not exists(select 1 from public.factions where id=p_faction) then raise exception 'Faction inconnue';end if;
 update public.faction_members set faction_id=p_faction,role='member' where user_id=uid;
end;$$;

create function public.play_campaign(p_code text,p_action text,p_investment integer,p_card text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();cfg jsonb;a jsonb;r public.player_resources;d public.departments;s public.seasons;f text;ticks integer;v_energy integer;v_budget integer;v_militants integer;carry integer;gain integer;mult numeric;previous jsonb;result jsonb;cid uuid;day date:=(now() at time zone 'UTC')::date;
begin
 if uid is null then raise exception 'Connexion requise';end if;
 if p_request_id is null then raise exception 'Identifiant de requête requis';end if;
 select * into r from public.player_resources where user_id=uid for update;
 if not found then raise exception 'Profil indisponible';end if;
 select response into previous from public.campaigns where user_id=uid and request_id=p_request_id;
 if previous is not null then return previous;end if;
 if exists(select 1 from public.profiles where id=uid and banned) then raise exception 'Compte suspendu';end if;
 select value into cfg from public.game_config where id;
 a:=cfg->'actions'->p_action;
 if a is null then raise exception 'Action inconnue';end if;
 if p_investment is null or p_investment<(cfg->>'minInfluence')::integer or p_investment>(cfg->>'maxInfluence')::integer then raise exception 'Investissement invalide';end if;
 if now()<r.last_action_at+make_interval(secs=>(cfg->>'cooldownSeconds')::integer) then raise exception 'Attendez la fin du délai entre deux campagnes';end if;
 select * into s from public.seasons where phase<>'finished' order by starts_at desc limit 1 for share;
 if not found or s.phase<>'expansion' or now()>=s.ends_at then raise exception 'La campagne de cette saison est terminée';end if;
 select * into d from public.departments where code=p_code for update;
 if not found then raise exception 'Territoire inconnu';end if;
 select faction_id into f from public.faction_members where user_id=uid;
 ticks:=greatest(0,floor(extract(epoch from(now()-r.updated_at))/((cfg->>'energyMinutes')::integer*60))::integer);
 v_energy:=least((cfg->>'energyCap')::integer,r.energy+ticks);
 v_budget:=least((cfg->>'budgetCap')::integer,r.budget+ticks*floor((cfg->>'budgetHourly')::numeric*(cfg->>'energyMinutes')::numeric/60)::integer);
 v_militants:=least((cfg->>'militantCap')::integer,r.militants+(ticks*2+r.militant_carry)/10);carry:=(ticks*2+r.militant_carry)%10;
 if v_energy<(a->>'energy')::integer or v_budget<(a->>'budget')::integer or v_militants<(a->>'militants')::integer or r.influence<p_investment then raise exception 'Ressources insuffisantes';end if;
 mult:=(a->>'multiplier')::numeric;
 if p_card is not null then
  if not exists(select 1 from public.cards where id=p_card and ((p_action='defend' and kind='defense') or (p_action<>'defend' and kind='campaign'))) then raise exception 'Carte incompatible';end if;
  perform 1 from public.player_cards where user_id=uid and card_id=p_card and quantity>0 for update;
  if not found then raise exception 'Carte indisponible';end if;
  mult:=mult*(cfg->'cards'->>p_card)::numeric;
  if mult is null then raise exception 'Configuration carte indisponible';end if;
  update public.player_cards set quantity=quantity-1 where user_id=uid and card_id=p_card;
 end if;
 gain:=greatest(1,least((cfg->>'maxGain')::integer,round(((p_investment*(cfg->>'offenseInfluence')::numeric+(a->>'militants')::numeric*(cfg->>'offenseMilitants')::numeric)*mult*(1+(random()*2-1)*(cfg->>'randomRange')::numeric)-d.defense*(cfg->>'defenseCoefficient')::numeric)*(cfg->>'gainScale')::numeric*10)::integer));
 update public.territory_influence set points=points+gain where season_id=s.id and department_code=p_code and faction_id=f;
 if not found then raise exception 'Influence du territoire indisponible';end if;
 if p_action='defend' then update public.departments set defense=least(100,defense+3) where code=p_code;end if;
 update public.player_resources set energy=v_energy-(a->>'energy')::integer,budget=v_budget-(a->>'budget')::integer,militants=v_militants-(a->>'militants')::integer,influence=r.influence-p_investment+gain/2,militant_carry=carry,updated_at=r.updated_at+make_interval(mins=>ticks*(cfg->>'energyMinutes')::integer),last_action_at=now(),mission_day=day,daily_campaigns=case when mission_day=day then daily_campaigns+1 else 1 end,daily_defenses=case when mission_day=day then daily_defenses else 0 end+case when p_action='defend' then 1 else 0 end where user_id=uid;
 update public.profiles set xp=xp+25,campaigns=campaigns+1,defenses=defenses+case when p_action='defend' then 1 else 0 end where id=uid;
 result:=jsonb_build_object('gain',gain,'requestId',p_request_id,'message',(a->>'name')||' : +'||gain||' points d’influence en '||d.name||'.');
 insert into public.campaigns(request_id,user_id,season_id,department_code,action,investment,gain,response) values(p_request_id,uid,s.id,p_code,p_action,p_investment,gain,result) returning id into cid;
 insert into public.battles(id,season_id,department_code,faction_id,gain,defensive) values(cid,s.id,p_code,f,gain,p_action='defend');
 -- One useful event per campaign, bounded to 100 retained feed events.
 insert into public.game_events(season_id,message) values(s.id,(a->>'name')||' en '||d.name||' : +'||gain||' points d’influence pour '||(select name from public.factions where id=f)||'.');
 delete from public.game_events where id in(select id from public.game_events order by created_at desc offset 100);
 return result;
end;$$;

create function public.claim_mission(p_mission text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();r public.player_resources;key text;progress integer;target integer;
begin
 if uid is null then raise exception 'Connexion requise';end if;
 select * into r from public.player_resources where user_id=uid for update;
 if exists(select 1 from public.profiles where id=uid and banned) then raise exception 'Compte suspendu';end if;
 if p_mission is null or p_mission not in ('campaigns','defenses') then raise exception 'Mission inconnue';end if;
 key:=to_char(now() at time zone 'UTC','YYYY-MM-DD')||':'||p_mission;
 if r.claimed ? key then raise exception 'Récompense déjà reçue';end if;
 progress:=case when r.mission_day<>(now() at time zone 'UTC')::date or r.mission_day is null then 0 when p_mission='campaigns' then r.daily_campaigns else r.daily_defenses end;
 target:=case when p_mission='campaigns' then 3 else 2 end;
 if progress<target then raise exception 'Mission incomplète';end if;
 update public.player_resources set influence=influence+50,budget=least(10000,budget+200),claimed=(select coalesce(jsonb_agg(x),'[]') from(select x from jsonb_array_elements(r.claimed||jsonb_build_array(key)) with ordinality as a(x,n) order by n desc limit 20) q) where user_id=uid;
 update public.profiles set xp=xp+50 where id=uid;
 update public.player_cards set quantity=least(20,quantity+1) where user_id=uid and card_id=case when p_mission='campaigns' then 'grand-meeting' else 'bastion' end;
end;$$;

create function public.advance_season() returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.seasons;total numeric;v_winner text;
begin
 if auth.uid() is null then raise exception 'Connexion requise';end if;
 select * into s from public.seasons order by starts_at desc limit 1 for update;
 if s.phase='finished' then return;end if;
 if s.phase='expansion' then
  if now()<s.ends_at then raise exception 'Le premier tour n’est pas encore ouvert';end if;
  insert into public.season_rankings(season_id,faction_id,round,score)
  select s.id,q.faction_id,1,avg(q.share) from(select t.faction_id,100.0*t.points/nullif(sum(t.points) over(partition by t.department_code),0) as share from public.territory_influence t where t.season_id=s.id) q group by q.faction_id;
  update public.seasons set phase='runoff' where id=s.id;
  insert into public.game_events(season_id,message) values(s.id,'Premier tour fictif terminé. Les deux finalistes entrent en jeu.');
 elsif s.phase='runoff' then
  if now()<s.ends_at+interval '2 days' then raise exception 'Le second tour s’ouvre 48 heures après le premier';end if;
  insert into public.season_rankings(season_id,faction_id,round,score)
  select s.id,r.faction_id,2,r.score+least(5,(select count(*) from public.season_supports where season_id=s.id and finalist=r.faction_id)*0.1) from public.season_rankings r where r.season_id=s.id and r.round=1 order by r.score desc,r.faction_id limit 2;
  select sum(score) into total from public.season_rankings where season_id=s.id and round=2;
  update public.season_rankings set score=100*score/nullif(total,0) where season_id=s.id and round=2;
  select faction_id into v_winner from public.season_rankings where season_id=s.id and round=2 order by score desc,faction_id limit 1;
  update public.seasons set phase='finished',winner=v_winner where id=s.id;
  insert into public.game_events(season_id,message) values(s.id,'Président de la saison : '||(select name from public.factions where id=v_winner)||'. Résultat fictif du jeu.');
 end if;
end;$$;

create function public.support_finalist(p_faction text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();s public.seasons;own text;
begin
 if uid is null then raise exception 'Connexion requise';end if;
 select * into s from public.seasons where phase='runoff' for share;
 if not found or now()>=s.ends_at+interval '2 days' then raise exception 'Phase de soutien fermée';end if;
 if not exists(select 1 from(select faction_id from public.season_rankings where season_id=s.id and round=1 order by score desc,faction_id limit 2) q where faction_id=p_faction) then raise exception 'Finaliste invalide';end if;
 select faction_id into own from public.faction_members where user_id=uid;
 if exists(select 1 from(select faction_id from public.season_rankings where season_id=s.id and round=1 order by score desc,faction_id limit 2) q where faction_id=own) then raise exception 'Votre faction est déjà finaliste';end if;
 insert into public.season_supports(season_id,user_id,finalist) values(s.id,uid,p_faction) on conflict do nothing;
end;$$;

create function public.game_snapshot() returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();r public.player_resources;p public.profiles;s public.seasons;cfg jsonb;f text;territories jsonb;results jsonb;events jsonb;inventory jsonb;rankings jsonb;ticks integer;
begin
 if uid is null then raise exception 'Connexion requise';end if;
 select * into p from public.profiles where id=uid;if not found then raise exception 'Profil indisponible';end if;
 if p.banned then raise exception 'Compte suspendu';end if;
 select * into r from public.player_resources where user_id=uid;
 select * into s from public.seasons order by starts_at desc limit 1;
 select value into cfg from public.game_config where id;
 select faction_id into f from public.faction_members where user_id=uid;
 ticks:=greatest(0,floor(extract(epoch from(now()-r.updated_at))/((cfg->>'energyMinutes')::integer*60))::integer);
 select jsonb_agg(jsonb_build_object('code',d.code,'name',d.name,'region',reg.name,'defense',d.defense,'mobilization',d.mobilization,'bonus',d.bonus,'influence',(select jsonb_object_agg(faction_id,points) from public.territory_influence where season_id=s.id and department_code=d.code)) order by d.code) into territories from public.departments d join public.regions reg on reg.id=d.region_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'message',message,'createdAt',extract(epoch from created_at)*1000)),'[]') into events from(select * from public.game_events where season_id=s.id order by created_at desc limit 10) q;
 select coalesce(jsonb_object_agg(card_id,quantity),'{}') into inventory from public.player_cards where user_id=uid;
 select coalesce(jsonb_agg(jsonb_build_object('id',faction_id,'score',score) order by score desc,faction_id),'[]') into results from public.season_rankings where season_id=s.id and round=case when s.phase='finished' then 2 else 1 end;
 select coalesce(jsonb_agg(jsonb_build_object('username',username,'xp',xp,'faction',faction_id)),'[]') into rankings from(select pr.username,pr.xp,m.faction_id from public.profiles pr join public.faction_members m on m.user_id=pr.id where not pr.banned order by pr.xp desc,pr.id limit 25) q;
 return jsonb_build_object('admin',public.is_game_admin(),'rankings',rankings,'state',jsonb_build_object('rules',cfg,'requests','[]'::jsonb,'territories',territories,'events',events,'player',jsonb_build_object('id',uid,'username',p.username,'faction',f,'energy',r.energy,'budget',r.budget,'militants',r.militants,'influence',r.influence,'xp',p.xp,'campaigns',p.campaigns,'defenses',p.defenses,'lastUpdate',extract(epoch from r.updated_at)*1000,'lastAction',coalesce(extract(epoch from r.last_action_at)*1000,0),'cards',inventory,'claimed',r.claimed,'militantCarry',r.militant_carry,'missionDay',r.mission_day,'daily',jsonb_build_object('campaigns',r.daily_campaigns,'defenses',r.daily_defenses)),'season',jsonb_build_object('id',s.id,'name',s.name,'start',extract(epoch from s.starts_at)*1000,'end',extract(epoch from s.ends_at)*1000,'phase',s.phase,'results',results,'winner',s.winner,'support',(select finalist from public.season_supports where season_id=s.id and user_id=uid))));
end;$$;

create function public.admin_configure(p_patch jsonb) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_game_admin() then raise exception 'Administration réservée';end if;
 if jsonb_typeof(p_patch)<>'object' or exists(select 1 from jsonb_object_keys(p_patch) k where k<>'cooldownSeconds') then raise exception 'Seul le délai est modifiable dans le MVP';end if;
 if (p_patch->>'cooldownSeconds')::integer not between 10 and 3600 then raise exception 'Délai invalide';end if;
 update public.game_config set value=value||p_patch,version=version+1 where id;
end;$$;
create function public.admin_end_season() returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_game_admin() then raise exception 'Administration réservée';end if;
 update public.seasons set ends_at=greatest(starts_at+interval '1 second',now()-interval '1 second') where phase='expansion';
 perform public.advance_season();
end;$$;
create function public.admin_start_season() returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare sid uuid;begin
 if not public.is_game_admin() then raise exception 'Administration réservée';end if;
 if exists(select 1 from public.seasons where phase<>'finished') then raise exception 'Terminez la saison active avant d’en ouvrir une autre';end if;
 insert into public.seasons(name) values('La conquête') returning id into sid;
 insert into public.territory_influence(season_id,department_code,faction_id,points)
 select sid,d.code,f.id,100 from public.departments d cross join public.factions f;
 update public.player_resources set energy=100,budget=1600,militants=120,influence=250,militant_carry=0,updated_at=now(),last_action_at=null,mission_day=null,daily_campaigns=0,daily_defenses=0,claimed='[]';
 update public.departments set defense=30;
 update public.player_cards set quantity=case when card_id='grand-meeting' then 3 else 2 end;
 -- Bounded retention: three seasons of actions; preserve all season results.
 delete from public.campaigns where season_id in(select id from public.seasons order by starts_at desc offset 3);
 delete from public.game_events where created_at<now()-interval '30 days';
end;$$;
-- PostgreSQL grants EXECUTE to PUBLIC by default: explicitly remove this for every RPC.
do $$declare name text;begin
 foreach name in array array['is_game_admin()','create_game_profile()','join_faction(text)','play_campaign(text,text,integer,text,uuid)','claim_mission(text)','advance_season()','support_finalist(text)','game_snapshot()','admin_configure(jsonb)','admin_end_season()','admin_start_season()'] loop
 execute 'revoke all on function public.'||name||' from public, anon';
 execute 'grant execute on function public.'||name||' to authenticated';
 end loop;
end$$;

-- Initial, entirely fictional game state. Geographic labels are real.
insert into public.game_config(id,value) values(true,'{"version": 1, "energyCap": 100, "energyMinutes": 6, "militantCap": 500, "budgetCap": 10000, "budgetHourly": 40, "militantsHourly": 2, "cooldownSeconds": 30, "controlThreshold": 50, "minInfluence": 10, "maxInfluence": 100, "randomRange": 0.08, "offenseInfluence": 1, "offenseMilitants": 1.5, "defenseCoefficient": 0.4, "gainScale": 0.02, "maxGain": 35, "cards": {"grand-meeting": 1.25, "bastion": 1.2}, "actions": {"meeting": {"name": "Meeting local", "energy": 15, "budget": 120, "militants": 3, "multiplier": 1.1}, "door": {"name": "Porte-à-porte", "energy": 10, "budget": 60, "militants": 5, "multiplier": 1}, "digital": {"name": "Campagne numérique", "energy": 12, "budget": 100, "militants": 0, "multiplier": 0.95}, "defend": {"name": "Défense territoriale", "energy": 10, "budget": 80, "militants": 2, "multiplier": 1}}}'::jsonb);
insert into public.factions values ('horizon','Horizon commun','#8b7bff','Construire, ensemble.'),('canopy','Canopée','#57d5a0','Enraciner le changement.'),('impulse','Nouvel élan','#ff987c','Faire bouger les lignes.'),('atlas','Union Atlas','#5aa9ff','Unir les territoires.'),('aurora','L’Aurore','#e5be62','Un nouvel horizon.');
insert into public.regions values ('0','Auvergne-Rhône-Alpes'),('1','Bourgogne-Franche-Comté'),('2','Bretagne'),('3','Centre-Val de Loire'),('4','Corse'),('5','Grand Est'),('6','Guadeloupe'),('7','Guyane'),('8','Hauts-de-France'),('9','La Réunion'),('10','Martinique'),('11','Mayotte'),('12','Normandie'),('13','Nouvelle-Aquitaine'),('14','Occitanie'),('15','Pays de la Loire'),('16','Provence-Alpes-Côte d''Azur'),('17','Île-de-France');
insert into public.departments(code,name,region_id,defense,mobilization,bonus) values ('01','Ain','0',20,15,'Place forte'),('02','Aisne','8',25,20,'Mobilisation locale'),('03','Allier','0',30,25,'Mobilisation locale'),('04','Alpes-de-Haute-Provence','16',35,30,'Mobilisation locale'),('05','Hautes-Alpes','16',40,15,'Mobilisation locale'),('06','Alpes-Maritimes','16',20,20,'Mobilisation locale'),('07','Ardèche','0',25,25,'Mobilisation locale'),('08','Ardennes','5',30,30,'Place forte'),('09','Ariège','14',35,15,'Mobilisation locale'),('10','Aube','5',40,20,'Mobilisation locale'),('11','Aude','14',20,25,'Mobilisation locale'),('12','Aveyron','14',25,30,'Mobilisation locale'),('13','Bouches-du-Rhône','16',30,15,'Mobilisation locale'),('14','Calvados','12',35,20,'Mobilisation locale'),('15','Cantal','0',40,25,'Place forte'),('16','Charente','13',20,30,'Mobilisation locale'),('17','Charente-Maritime','13',25,15,'Mobilisation locale'),('18','Cher','3',30,20,'Mobilisation locale'),('19','Corrèze','13',35,25,'Mobilisation locale'),('21','Côte-d''Or','1',40,30,'Mobilisation locale'),('22','Côtes-d''Armor','2',20,15,'Mobilisation locale'),('23','Creuse','13',25,20,'Place forte'),('24','Dordogne','13',30,25,'Mobilisation locale'),('25','Doubs','1',35,30,'Mobilisation locale'),('26','Drôme','0',40,15,'Mobilisation locale'),('27','Eure','12',20,20,'Mobilisation locale'),('28','Eure-et-Loir','3',25,25,'Mobilisation locale'),('29','Finistère','2',30,30,'Mobilisation locale'),('2A','Corse-du-Sud','4',35,15,'Place forte'),('2B','Haute-Corse','4',40,20,'Mobilisation locale'),('30','Gard','14',20,25,'Mobilisation locale'),('31','Haute-Garonne','14',25,30,'Mobilisation locale'),('32','Gers','14',30,15,'Mobilisation locale'),('33','Gironde','13',35,20,'Mobilisation locale'),('34','Hérault','14',40,25,'Mobilisation locale'),('35','Ille-et-Vilaine','2',20,30,'Place forte'),('36','Indre','3',25,15,'Mobilisation locale'),('37','Indre-et-Loire','3',30,20,'Mobilisation locale'),('38','Isère','0',35,25,'Mobilisation locale'),('39','Jura','1',40,30,'Mobilisation locale'),('40','Landes','13',20,15,'Mobilisation locale'),('41','Loir-et-Cher','3',25,20,'Mobilisation locale'),('42','Loire','0',30,25,'Place forte'),('43','Haute-Loire','0',35,30,'Mobilisation locale'),('44','Loire-Atlantique','15',40,15,'Mobilisation locale'),('45','Loiret','3',20,20,'Mobilisation locale'),('46','Lot','14',25,25,'Mobilisation locale'),('47','Lot-et-Garonne','13',30,30,'Mobilisation locale'),('48','Lozère','14',35,15,'Mobilisation locale'),('49','Maine-et-Loire','15',40,20,'Place forte'),('50','Manche','12',20,25,'Mobilisation locale'),('51','Marne','5',25,30,'Mobilisation locale'),('52','Haute-Marne','5',30,15,'Mobilisation locale'),('53','Mayenne','15',35,20,'Mobilisation locale'),('54','Meurthe-et-Moselle','5',40,25,'Mobilisation locale'),('55','Meuse','5',20,30,'Mobilisation locale'),('56','Morbihan','2',25,15,'Place forte'),('57','Moselle','5',30,20,'Mobilisation locale'),('58','Nièvre','1',35,25,'Mobilisation locale'),('59','Nord','8',40,30,'Mobilisation locale'),('60','Oise','8',20,15,'Mobilisation locale'),('61','Orne','12',25,20,'Mobilisation locale'),('62','Pas-de-Calais','8',30,25,'Mobilisation locale'),('63','Puy-de-Dôme','0',35,30,'Place forte'),('64','Pyrénées-Atlantiques','13',40,15,'Mobilisation locale'),('65','Hautes-Pyrénées','14',20,20,'Mobilisation locale'),('66','Pyrénées-Orientales','14',25,25,'Mobilisation locale'),('67','Bas-Rhin','5',30,30,'Mobilisation locale'),('68','Haut-Rhin','5',35,15,'Mobilisation locale'),('69','Rhône','0',40,20,'Mobilisation locale'),('70','Haute-Saône','1',20,25,'Place forte'),('71','Saône-et-Loire','1',25,30,'Mobilisation locale'),('72','Sarthe','15',30,15,'Mobilisation locale'),('73','Savoie','0',35,20,'Mobilisation locale'),('74','Haute-Savoie','0',40,25,'Mobilisation locale'),('75','Paris','17',20,30,'Mobilisation locale'),('76','Seine-Maritime','12',25,15,'Mobilisation locale'),('77','Seine-et-Marne','17',30,20,'Place forte'),('78','Yvelines','17',35,25,'Mobilisation locale'),('79','Deux-Sèvres','13',40,30,'Mobilisation locale'),('80','Somme','8',20,15,'Mobilisation locale'),('81','Tarn','14',25,20,'Mobilisation locale'),('82','Tarn-et-Garonne','14',30,25,'Mobilisation locale'),('83','Var','16',35,30,'Mobilisation locale'),('84','Vaucluse','16',40,15,'Place forte'),('85','Vendée','15',20,20,'Mobilisation locale'),('86','Vienne','13',25,25,'Mobilisation locale'),('87','Haute-Vienne','13',30,30,'Mobilisation locale'),('88','Vosges','5',35,15,'Mobilisation locale'),('89','Yonne','1',40,20,'Mobilisation locale'),('90','Territoire de Belfort','1',20,25,'Mobilisation locale'),('91','Essonne','17',25,30,'Place forte'),('92','Hauts-de-Seine','17',30,15,'Mobilisation locale'),('93','Seine-Saint-Denis','17',35,20,'Mobilisation locale'),('94','Val-de-Marne','17',40,25,'Mobilisation locale'),('95','Val-d''Oise','17',20,30,'Mobilisation locale'),('971','Guadeloupe','6',25,15,'Mobilisation locale'),('972','Martinique','10',30,20,'Mobilisation locale'),('973','Guyane','7',35,25,'Place forte'),('974','La Réunion','9',40,30,'Mobilisation locale'),('976','Mayotte','11',20,15,'Mobilisation locale');
insert into public.cards values('grand-meeting','Grand meeting','campaign','rare'),('bastion','Bastion renforcé','defense','common');
insert into public.seasons(name) values('La conquête');
insert into public.territory_influence select s.id,d.code,f.id,case when ((row_number() over (partition by f.id order by d.code))-1)%5=case f.id when 'horizon' then 0 when 'canopy' then 1 when 'impulse' then 2 when 'atlas' then 3 else 4 end then 320 else 60 end from public.seasons s cross join public.departments d cross join public.factions f;
insert into public.game_events(season_id,message) select id,'Une nouvelle saison commence. Toutes les influences sont des données fictives du jeu.' from public.seasons;
commit;
