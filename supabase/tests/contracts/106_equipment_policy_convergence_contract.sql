-- 106 contract - complete Equipment policy convergence.
do $$
declare
  v_qual text;
  v_check text;
begin
  if exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename like 'equipacion%'
      and (
        coalesce(qual,'') like '%has_any_role%administrador%club%'
        or coalesce(with_check,'') like '%has_any_role%administrador%club%'
      )
  ) then
    raise exception '106: legacy equipment role policy remains';
  end if;

  select coalesce(qual,''),coalesce(with_check,'') into v_qual,v_check
  from pg_policies
  where schemaname='public' and tablename='equipacion_personas_temporada'
    and policyname='equipacion_personas_temporada_equipment_manage';
  if v_qual not like '%has_capability%equipment.manage%'
     or v_check not like '%has_capability%equipment.manage%' then
    raise exception '106: persona-season equipment policy not converged';
  end if;

  select coalesce(qual,''),coalesce(with_check,'') into v_qual,v_check
  from pg_policies
  where schemaname='public' and tablename='equipacion_tallas_persona'
    and policyname='equipacion_tallas_write';
  if v_qual not like '%has_capability%equipment.manage%'
     or v_qual not like '%can_manage_equipacion_tallas%'
     or v_qual not like '%confirmada_at%'
     or v_check not like '%has_capability%equipment.manage%'
     or v_check not like '%can_manage_equipacion_tallas%'
     or v_check not like '%confirmada_at%' then
    raise exception '106: personal size policy lost capability or personal pre-confirmation access';
  end if;

  select coalesce(qual,''),coalesce(with_check,'') into v_qual,v_check
  from pg_policies
  where schemaname='public' and tablename='equipacion_tallas_excepcion'
    and policyname='equipacion_tallas_excepcion_write';
  if v_qual not like '%has_capability%equipment.manage%'
     or v_qual not like '%can_manage_equipacion_tallas%'
     or v_check not like '%has_capability%equipment.manage%'
     or v_check not like '%can_manage_equipacion_tallas%' then
    raise exception '106: size-exception policy lost capability or personal access';
  end if;

  if exists (
    select 1 from private.rol_capacidades rc
    join public.roles r on r.id=rc.rol_id
    where r.codigo='entrenador' and rc.capacidad_codigo like 'equipment.%manage'
  ) then
    raise exception '106: entrenador received equipment management';
  end if;
end $$;

select '106_equipment_policy_convergence_contract' contract,'PASS' result;
