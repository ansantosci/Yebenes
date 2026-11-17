-- 091_function_search_path_hardening_contract.sql
do $$
declare
  r record;
  fn_oid oid;
  cfg text[];
  cnt integer;
begin
  -- Exact 16-function surface must exist and have an explicit safe search_path.
  for r in
    select * from (values
      ('private','demo_access_persona_id','p_key text'),
      ('private','demo_uuid','p_key text'),
      ('private','test_s_coach_id','p_n bigint'),
      ('private','test_s_coach_id','p_n integer'),
      ('private','test_s_coach_person_id','p_n bigint'),
      ('private','test_s_coach_person_id','p_n integer'),
      ('private','test_s_player_id','p_team_code text, p_slot bigint'),
      ('private','test_s_player_id','p_team_code text, p_slot integer'),
      ('private','test_s_player_person_id','p_team_code text, p_slot bigint'),
      ('private','test_s_player_person_id','p_team_code text, p_slot integer'),
      ('private','test_s_tutor_person_id','p_team_code text'),
      ('private','test_uuid','p_key text'),
      ('private','equipacion_recepcion_linea_inmutable',''),
      ('public','calcular_categoria_inscripcion',''),
      ('public','set_updated_at',''),
      ('public','validar_tutor_menor_inscripcion','')
    ) as x(schema_name,function_name,identity_args)
  loop
    select p.oid,p.proconfig into fn_oid,cfg
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname=r.schema_name
      and p.proname=r.function_name
      and pg_get_function_identity_arguments(p.oid)=r.identity_args;

    if fn_oid is null then
      raise exception '091: missing %.%(%)',r.schema_name,r.function_name,r.identity_args;
    end if;

    if not ('search_path=pg_catalog, public, private'=any(coalesce(cfg,array[]::text[]))) then
      raise exception '091: unsafe/missing search_path on %.%(%): %',
        r.schema_name,r.function_name,r.identity_args,cfg;
    end if;
  end loop;

  -- No mutable function should remain in public/private after this hardening set.
  select count(*) into cnt
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private')
    and p.prokind='f'
    and not exists (
      select 1 from unnest(coalesce(p.proconfig,array[]::text[])) c
      where c like 'search_path=%'
    );

  if cnt <> 0 then
    raise exception '091: % mutable public/private functions remain',cnt;
  end if;

  -- Productive trigger bindings must remain intact.
  select count(*) into cnt
  from pg_trigger t
  join pg_proc p on p.oid=t.tgfoid
  join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal
    and n.nspname='private'
    and p.proname='equipacion_recepcion_linea_inmutable';
  if cnt <> 2 then raise exception '091: expected 2 equipacion reception immutability triggers, found %',cnt; end if;

  select count(*) into cnt
  from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal and n.nspname='public' and p.proname='calcular_categoria_inscripcion';
  if cnt <> 1 then raise exception '091: calcular_categoria_inscripcion trigger count=%',cnt; end if;

  select count(*) into cnt
  from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal and n.nspname='public' and p.proname='set_updated_at';
  if cnt <> 30 then raise exception '091: set_updated_at trigger count=% expected 30',cnt; end if;

  select count(*) into cnt
  from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
  where not t.tgisinternal and n.nspname='public' and p.proname='validar_tutor_menor_inscripcion';
  if cnt <> 1 then raise exception '091: validar_tutor_menor_inscripcion trigger count=%',cnt; end if;

  -- Trigger functions must not be callable directly by client roles.
  for r in
    select * from (values
      ('private','equipacion_recepcion_linea_inmutable',''),
      ('public','calcular_categoria_inscripcion',''),
      ('public','set_updated_at',''),
      ('public','validar_tutor_menor_inscripcion','')
    ) as x(schema_name,function_name,identity_args)
  loop
    select p.oid into fn_oid
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname=r.schema_name and p.proname=r.function_name
      and pg_get_function_identity_arguments(p.oid)=r.identity_args;

    if has_function_privilege('anon',fn_oid,'EXECUTE')
       or has_function_privilege('authenticated',fn_oid,'EXECUTE') then
      raise exception '091: client EXECUTE remains on %.%()',r.schema_name,r.function_name;
    end if;
  end loop;
end $$;

select 'function_search_path_hardening_contract' contract,'PASS' result;
