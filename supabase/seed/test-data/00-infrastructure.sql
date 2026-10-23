-- TEST dataset infrastructure. TEST-only; do not deploy to DEMO/PROD.
begin;
create table if not exists private.test_datasets (
  id text primary key,
  version text not null,
  scenario text not null default 'BASELINE',
  loaded_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create table if not exists private.test_dataset_entities (
  dataset_id text not null references private.test_datasets(id) on delete cascade,
  table_name text not null,
  entity_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(dataset_id, table_name, entity_id)
);
revoke all on private.test_datasets from public, anon, authenticated;
revoke all on private.test_dataset_entities from public, anon, authenticated;
create or replace function private.test_uuid(p_key text) returns uuid language sql immutable as $$
  select (substr(md5('yebenes:test:'||p_key),1,8)||'-'||substr(md5('yebenes:test:'||p_key),9,4)||'-'||substr(md5('yebenes:test:'||p_key),13,4)||'-'||substr(md5('yebenes:test:'||p_key),17,4)||'-'||substr(md5('yebenes:test:'||p_key),21,12))::uuid;
$$;
revoke all on function private.test_uuid(text) from public;

-- TEST-S access mappings: reuse permanent TEST-ACCESS Personas/facets for end-to-end login cases.
create or replace function private.test_s_player_person_id(p_team_code text,p_slot int) returns uuid language sql immutable as $$
  select case
    when p_team_code='CAD-A' and p_slot=1 then '10000000-0000-4000-8000-000000000006'::uuid
    when p_team_code='SEN-A' and p_slot=1 then '10000000-0000-4000-8000-000000000003'::uuid
    when p_team_code='SEN-A' and p_slot=2 then '10000000-0000-4000-8000-000000000007'::uuid
    when p_team_code='SEN-B' and p_slot=1 then '10000000-0000-4000-8000-000000000005'::uuid
    else private.test_uuid('player:'||p_team_code||':'||p_slot)
  end;
$$;
create or replace function private.test_s_player_id(p_team_code text,p_slot int) returns uuid language sql immutable as $$
  select case
    when p_team_code='CAD-A' and p_slot=1 then private.test_uuid('access-player:minor_player')
    when p_team_code='SEN-A' and p_slot=1 then private.test_uuid('access-player:coach_player')
    when p_team_code='SEN-A' and p_slot=2 then private.test_uuid('access-player:multiprofile')
    when p_team_code='SEN-B' and p_slot=1 then private.test_uuid('access-player:adult_player')
    else private.test_uuid('jugador:'||p_team_code||':'||p_slot)
  end;
$$;
create or replace function private.test_s_tutor_person_id(p_team_code text) returns uuid language sql immutable as $$
  select case when p_team_code='CAD-A' then '10000000-0000-4000-8000-000000000004'::uuid else private.test_uuid('tutor:'||p_team_code) end;
$$;
create or replace function private.test_s_coach_person_id(p_n int) returns uuid language sql immutable as $$
  select case
    when p_n=1 then '10000000-0000-4000-8000-000000000002'::uuid
    when p_n=11 then '10000000-0000-4000-8000-000000000003'::uuid
    when p_n=12 then '10000000-0000-4000-8000-000000000007'::uuid
    else private.test_uuid('coach-person:'||p_n)
  end;
$$;
create or replace function private.test_s_coach_id(p_n int) returns uuid language sql immutable as $$
  select case
    when p_n=1 then private.test_uuid('access-coach:coach')
    when p_n=11 then private.test_uuid('access-coach:coach_player')
    when p_n=12 then private.test_uuid('access-coach:multiprofile')
    else private.test_uuid('coach:'||p_n)
  end;
$$;
revoke all on function private.test_s_player_person_id(text,int) from public;
revoke all on function private.test_s_player_id(text,int) from public;
revoke all on function private.test_s_tutor_person_id(text) from public;
revoke all on function private.test_s_coach_person_id(int) from public;
revoke all on function private.test_s_coach_id(int) from public;
commit;
