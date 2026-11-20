-- Contract 102: persona_roles temporal validity is canonical and RBAC consumes it.
begin;

do $$
declare
  d date := date '2026-11-20';
begin
  if to_regprocedure('private.persona_role_is_active(date,date,date)') is null then
    raise exception '102 contract: private.persona_role_is_active(date,date,date) missing';
  end if;

  if not private.persona_role_is_active(null, null, d) then
    raise exception '102 contract: NULL/NULL role must be active';
  end if;
  if not private.persona_role_is_active(date '2026-07-01', null, d) then
    raise exception '102 contract: past start/open end role must be active';
  end if;
  if private.persona_role_is_active(date '2025-07-01', date '2026-06-30', d) then
    raise exception '102 contract: expired role must be inactive';
  end if;
  if private.persona_role_is_active(date '2027-07-01', null, d) then
    raise exception '102 contract: future role must be inactive';
  end if;

  if pg_get_functiondef('private.has_capability(text)'::regprocedure) not like '%persona_role_is_active%' then
    raise exception '102 contract: has_capability does not use canonical role validity';
  end if;
  if pg_get_functiondef('public.mis_capacidades()'::regprocedure) not like '%persona_role_is_active%' then
    raise exception '102 contract: mis_capacidades does not use canonical role validity';
  end if;
end $$;

rollback;
