-- 092_security_definer_internal_acl_hardening_contract.sql
do $$
declare r record; fn_oid oid; cnt integer; ret_type text;
begin
 for r in select * from (values
  ('public','procesar_mayorias_edad',''),
  ('public','procesar_preparacion_mayoria_edad',''),
  ('public','rls_auto_enable',''),
  ('public','auditar_cambios_entrenador_v92',''),
  ('public','trg_inicializar_requisitos_federativos','')
 ) x(schema_name,function_name,identity_args)
 loop
  select p.oid into fn_oid
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname=r.schema_name and p.proname=r.function_name
    and pg_get_function_identity_arguments(p.oid)=r.identity_args and p.prosecdef;
  if fn_oid is null then raise exception '092: missing/non-SECURITY-DEFINER %.%()',r.schema_name,r.function_name; end if;
  if has_function_privilege('anon',fn_oid,'EXECUTE')
     or has_function_privilege('authenticated',fn_oid,'EXECUTE') then
    raise exception '092: direct client EXECUTE remains on %.%()',r.schema_name,r.function_name;
  end if;
 end loop;

 select pg_get_function_result(p.oid) into ret_type
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='rls_auto_enable'
   and pg_get_function_identity_arguments(p.oid)='';
 if ret_type<>'event_trigger' then raise exception '092: rls_auto_enable return type changed: %',ret_type; end if;

 select count(*) into cnt from pg_trigger t join pg_proc p on p.oid=t.tgfoid
 join pg_namespace n on n.oid=p.pronamespace
 where not t.tgisinternal and n.nspname='public' and p.proname='auditar_cambios_entrenador_v92';
 if cnt<>3 then raise exception '092: audit trigger count=% expected 3',cnt; end if;

 select count(*) into cnt from pg_trigger t join pg_proc p on p.oid=t.tgfoid
 join pg_namespace n on n.oid=p.pronamespace
 where not t.tgisinternal and n.nspname='public' and p.proname='trg_inicializar_requisitos_federativos';
 if cnt<>1 then raise exception '092: federative init trigger count=% expected 1',cnt; end if;

 select p.oid into fn_oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='registrar_telemetria_sesion' and p.prosecdef limit 1;
 if fn_oid is null then raise exception '092: telemetry function missing'; end if;
 if not has_function_privilege('anon',fn_oid,'EXECUTE')
    or not has_function_privilege('authenticated',fn_oid,'EXECUTE') then
   raise exception '092: intentional telemetry anon/authenticated grant lost';
 end if;
end $$;
select 'security_definer_internal_acl_hardening_contract' contract,'PASS' result;
