-- V95.2.13 - Permanent synthetic login identities for DEMO.
-- These are deliberately independent from DEMO-S so a dataset refresh cannot
-- delete or change real DEMO users, nor the controlled demonstration logins.

begin;

create table if not exists private.demo_access_identities (
  key text primary key,
  persona_id uuid not null unique,
  email text not null unique,
  description text not null,
  created_at timestamptz not null default now()
);

create or replace function private.demo_access_persona_id(p_key text)
returns uuid
language sql
stable
as $$
  select persona_id
  from private.demo_access_identities
  where key = p_key;
$$;

revoke all on table private.demo_access_identities from public, anon, authenticated;
revoke all on function private.demo_access_persona_id(text) from public, anon, authenticated;

commit;

select '050_v95_2_13_demo_access_identities' as migration, 'PASS' as result;
