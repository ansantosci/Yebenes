-- 104 contract - Structure authorization must derive from structure.manage.
do $$
declare
  v_def text;
  v_qual text;
  v_check text;
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='equipos'
      and policyname='equipos_structure_manage_write'
  ) then raise exception '104 contract: equipos structure policy missing'; end if;

  select coalesce(qual,''),coalesce(with_check,'') into v_qual,v_check
  from pg_policies
  where schemaname='public' and tablename='equipos'
    and policyname='equipos_structure_manage_write';
  if v_qual not like '%has_capability%structure.manage%'
     or v_check not like '%has_capability%structure.manage%' then
    raise exception '104 contract: equipos write policy does not use structure.manage';
  end if;

  select pg_get_functiondef('public.activar_temporada(uuid)'::regprocedure) into v_def;
  if v_def not like '%has_capability%structure.manage%' or v_def like '%has_any_role%' then
    raise exception '104 contract: activar_temporada not converged';
  end if;

  select pg_get_functiondef('public.cerrar_temporada(uuid,text)'::regprocedure) into v_def;
  if v_def not like '%has_capability%structure.manage%' or v_def like '%has_any_role%' then
    raise exception '104 contract: cerrar_temporada not converged';
  end if;

  select pg_get_functiondef('public.configurar_economia_equipo(uuid,numeric,boolean,boolean,text)'::regprocedure) into v_def;
  if v_def not like '%has_capability%structure.manage%' or v_def like '%has_any_role%' then
    raise exception '104 contract: configurar_economia_equipo not converged';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='historico_estados_temporada'
      and policyname='historico_estados_temporada_structure_read'
      and qual like '%has_capability%structure.manage%'
  ) then raise exception '104 contract: season history policy not converged'; end if;

  if exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='equipos'
      and policyname='equipos_club_admin_write'
  ) then raise exception '104 contract: legacy equipos role policy still present'; end if;
end $$;
