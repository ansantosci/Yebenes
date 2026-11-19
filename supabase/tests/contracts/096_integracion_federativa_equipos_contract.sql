\set ON_ERROR_STOP on

begin;

do $$
declare
  v_rel regclass;
  v_rls boolean;
  v_bad integer;
  v_cols integer;
  v_policy integer;
  v_team uuid;
  v_season uuid;
  v_category uuid;
  v_row uuid;
begin
  v_rel := to_regclass('public.equipo_integraciones_federacion');
  if v_rel is null then raise exception '096: falta public.equipo_integraciones_federacion'; end if;

  select c.relrowsecurity into v_rls from pg_class c where c.oid=v_rel;
  if not coalesce(v_rls,false) then raise exception '096: RLS no activo'; end if;

  select count(*) into v_cols
  from information_schema.columns
  where table_schema='public' and table_name='equipo_integraciones_federacion'
    and column_name in ('equipo_id','proveedor','competition_id','group_id','game_type','external_team_id','config','activo','ultima_validacion_at','ultima_validacion_ok','ultima_validacion_mensaje');
  if v_cols <> 11 then raise exception '096: columnas esperadas incompletas: %',v_cols; end if;

  if has_table_privilege('anon','public.equipo_integraciones_federacion','SELECT')
     or has_table_privilege('anon','public.equipo_integraciones_federacion','INSERT')
     or has_table_privilege('anon','public.equipo_integraciones_federacion','UPDATE')
     or has_table_privilege('anon','public.equipo_integraciones_federacion','DELETE') then
    raise exception '096: anon no debe tener privilegios';
  end if;

  if not has_table_privilege('authenticated','public.equipo_integraciones_federacion','SELECT') then
    raise exception '096: authenticated debe poder leer';
  end if;

  select count(*) into v_policy
  from pg_policies
  where schemaname='public' and tablename='equipo_integraciones_federacion'
    and policyname in ('equipo_integraciones_federacion_read','equipo_integraciones_federacion_insert','equipo_integraciones_federacion_update','equipo_integraciones_federacion_delete');
  if v_policy <> 4 then raise exception '096: policies esperadas=4 encontradas=%',v_policy; end if;

  -- Fixture autocontenido: reutiliza columnas reales de temporada/categoria sin depender de TEST-S.
  select id into v_season from public.temporadas order by created_at nulls last, id limit 1;
  select id into v_category from public.categorias order by id limit 1;
  if v_season is null or v_category is null then
    raise exception '096: esquema base debe contener al menos temporada y categoria estructurales';
  end if;

  insert into public.equipos(temporada_id,categoria_id,nombre,codigo,genero,activo,modalidad)
  values(v_season,v_category,'096 CONTRACT RFFM','096-RFFM-'||substr(gen_random_uuid()::text,1,8),'mixto',true,'F7')
  returning id into v_team;

  insert into public.equipo_integraciones_federacion(
    equipo_id,proveedor,competition_id,group_id,game_type,external_team_id,config
  ) values (
    v_team,'RFFM','26738167','26738176','2','1252','{"contract":true}'::jsonb
  ) returning id into v_row;

  if v_row is null then raise exception '096: no se pudo crear configuracion'; end if;

  begin
    insert into public.equipo_integraciones_federacion(equipo_id,proveedor,competition_id,group_id,game_type)
    values(v_team,'RFFM','x','y','2');
    raise exception '096: se esperaba unicidad equipo+proveedor';
  exception when unique_violation then null;
  end;

  begin
    insert into public.equipo_integraciones_federacion(equipo_id,proveedor,competition_id,group_id,game_type,config)
    values(v_team,'OTRA','x','y','1','[]'::jsonb);
    raise exception '096: config array deberia rechazarse';
  exception when check_violation then null;
  end;

  select count(*) into v_bad
  from pg_trigger t
  join pg_proc p on p.oid=t.tgfoid
  join pg_namespace n on n.oid=p.pronamespace
  where t.tgrelid=v_rel and not t.tgisinternal
    and t.tgname='equipo_integraciones_federacion_updated_at'
    and not (n.nspname='public' and p.proname='set_updated_at');
  if v_bad <> 0 then raise exception '096: trigger updated_at incorrecto'; end if;
end $$;

select 'integracion_federativa_equipos_contract' as contract, 'PASS' as result;
rollback;
