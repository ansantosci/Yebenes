-- 091_function_search_path_hardening_contract.sql
-- Portable contract: validates only the productive surface hardened by migration 091.
-- TEST-S/DEMO support helpers are environment-specific and intentionally out of scope.
do $$
declare
  r record;
  fn_oid oid;
  cfg text[];
  cnt integer;
begin
  -- Productive surface: mandatory everywhere.
  for r in select * from (values
    ('private','equipacion_recepcion_linea_inmutable',''),
    ('public','calcular_categoria_inscripcion',''),
    ('public','set_updated_at',''),
    ('public','validar_tutor_menor_inscripcion','')
  ) x(schema_name,function_name,identity_args)
  loop
    select p.oid,p.proconfig into fn_oid,cfg
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname=r.schema_name and p.proname=r.function_name
      and pg_get_function_identity_arguments(p.oid)=r.identity_args;
    if fn_oid is null then raise exception '091: missing productive %.%(%).',r.schema_name,r.function_name,r.identity_args; end if;
    if not ('search_path=pg_catalog, public, private'=any(coalesce(cfg,array[]::text[]))) then
      raise exception '091: unsafe/missing search_path on productive %.%(%): %',r.schema_name,r.function_name,r.identity_args,cfg;
    end if;
  end loop;

  -- Environment-specific helpers (private.test_*, private.test_s_*, demo helpers)
  -- are deliberately excluded. They are test/support infrastructure and are not
  -- part of the productive hardening contract of migration 091.

  select count(*) into cnt from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal and n.nspname='private' and p.proname='equipacion_recepcion_linea_inmutable';
  if cnt<>2 then raise exception '091: expected 2 reception immutability triggers, found %',cnt; end if;
  select count(*) into cnt from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal and n.nspname='public' and p.proname='calcular_categoria_inscripcion';
  if cnt<>1 then raise exception '091: calcular_categoria_inscripcion trigger count=%',cnt; end if;
  select count(*) into cnt from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal and n.nspname='public' and p.proname='set_updated_at';
  if cnt<1 then raise exception '091: expected at least one active set_updated_at trigger, found %',cnt; end if;
  select count(*) into cnt from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal and n.nspname='public' and p.proname='validar_tutor_menor_inscripcion';
  if cnt<>1 then raise exception '091: validar_tutor_menor_inscripcion trigger count=%',cnt; end if;

  for r in select * from (values
    ('private','equipacion_recepcion_linea_inmutable',''),('public','calcular_categoria_inscripcion',''),
    ('public','set_updated_at',''),('public','validar_tutor_menor_inscripcion','')
  ) x(schema_name,function_name,identity_args)
  loop
    select p.oid into fn_oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname=r.schema_name and p.proname=r.function_name and pg_get_function_identity_arguments(p.oid)=r.identity_args;
    if has_function_privilege('anon',fn_oid,'EXECUTE') or has_function_privilege('authenticated',fn_oid,'EXECUTE') then
      raise exception '091: client EXECUTE remains on %.%()',r.schema_name,r.function_name;
    end if;
  end loop;
end $$;
select 'function_search_path_hardening_contract' contract,'PASS' result;
