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
commit;
