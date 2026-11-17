-- 090 contract evolved after 093: five InitPlan policies survive.
do $$
declare r record; expr text; stripped text; n integer;
begin
 select count(*) into n from pg_policies p where p.schemaname='public'
 and (p.tablename,p.policyname) in (
 ('entrenador_disponibilidad','entrenador_disponibilidad_read_v90_1'),
 ('entrenador_formaciones','entrenador_formaciones_read'),
 ('entrenador_licencias_rffm','entrenador_licencias_read'),
 ('entrenador_temporadas','entrenador_temporadas_self_read'),
 ('horarios_equipo','horarios_equipo_coach_read'))
 and p.cmd='SELECT' and p.permissive='PERMISSIVE'
 and p.roles=array['authenticated']::name[];
 if n<>5 then raise exception '090: expected 5 surviving authenticated SELECT policies after 093, found %',n; end if;

 for r in select p.tablename,p.policyname,p.qual from pg_policies p
 where p.schemaname='public' and (p.tablename,p.policyname) in (
 ('entrenador_disponibilidad','entrenador_disponibilidad_read_v90_1'),
 ('entrenador_formaciones','entrenador_formaciones_read'),
 ('entrenador_licencias_rffm','entrenador_licencias_read'),
 ('entrenador_temporadas','entrenador_temporadas_self_read'),
 ('horarios_equipo','horarios_equipo_coach_read'))
 loop
  expr:=lower(coalesce(r.qual,''));
  if expr!~'\(\s*select\s+auth\.uid\s*\(\s*\)(\s+as\s+uid)?\s*\)' then
   raise exception '090: %.% lost wrapped auth.uid()',r.tablename,r.policyname; end if;
  stripped:=regexp_replace(expr,'\(\s*select\s+auth\.uid\s*\(\s*\)(\s+as\s+uid)?\s*\)','','g');
  if stripped~'auth\.uid\s*\(\s*\)' then raise exception '090: %.% has direct auth.uid()',r.tablename,r.policyname; end if;
 end loop;

 if exists(select 1 from pg_policies where schemaname='public' and tablename='entrenador_disponibilidad'
 and policyname='entrenador_disponibilidad_self_read') then raise exception '090: retired policy exists'; end if;

 if not exists(select 1 from pg_policies where schemaname='public' and tablename='entrenador_formaciones'
 and policyname='entrenador_formaciones_write' and cmd='ALL' and roles=array['authenticated']::name[])
 then raise exception '090: entrenador_formaciones_write missing/changed'; end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='entrenador_licencias_rffm'
 and policyname='entrenador_licencias_write' and cmd='ALL' and roles=array['authenticated']::name[])
 then raise exception '090: entrenador_licencias_write missing/changed'; end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='entrenador_temporadas'
 and policyname='entrenador_temporadas_club' and cmd='ALL' and roles=array['authenticated']::name[])
 then raise exception '090: entrenador_temporadas_club missing/changed'; end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='horarios_equipo'
 and policyname='horarios_equipo_club' and cmd='ALL' and roles=array['authenticated']::name[])
 then raise exception '090: horarios_equipo_club missing/changed'; end if;
end $$;
select 'rls_auth_initialization_plan_contract' contract,'PASS' result;
