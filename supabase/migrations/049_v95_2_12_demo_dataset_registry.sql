-- V95.2.12 - Registro privado para datos sintéticos de demostración.
-- No crea identidades de acceso ni expone datos al cliente.

begin;

create table if not exists private.demo_datasets (
  id text primary key,
  version text not null,
  scenario text not null default 'BASELINE',
  loaded_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists private.demo_dataset_entities (
  dataset_id text not null references private.demo_datasets(id) on delete cascade,
  table_name text not null,
  entity_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (dataset_id, table_name, entity_id)
);

create or replace function private.demo_uuid(p_key text)
returns uuid
language sql
immutable
as $$
  select (
    substr(md5('yebenes:demo:' || p_key), 1, 8) || '-' ||
    substr(md5('yebenes:demo:' || p_key), 9, 4) || '-' ||
    substr(md5('yebenes:demo:' || p_key), 13, 4) || '-' ||
    substr(md5('yebenes:demo:' || p_key), 17, 4) || '-' ||
    substr(md5('yebenes:demo:' || p_key), 21, 12)
  )::uuid;
$$;

revoke all on table private.demo_datasets from public, anon, authenticated;
revoke all on table private.demo_dataset_entities from public, anon, authenticated;
revoke all on function private.demo_uuid(text) from public, anon, authenticated;

commit;

select '049_v95_2_12_demo_dataset_registry' as migration, 'PASS' as result;
