-- Contract 101: capability-based authorization is canonical and RFFM consumes it.
begin;

do $$
begin
  if to_regclass('private.capacidades') is null then raise exception '101 contract: private.capacidades missing'; end if;
  if to_regclass('private.rol_capacidades') is null then raise exception '101 contract: private.rol_capacidades missing'; end if;
  if to_regprocedure('private.has_capability(text)') is null then raise exception '101 contract: private.has_capability(text) missing'; end if;
  if to_regprocedure('public.mis_capacidades()') is null then raise exception '101 contract: public.mis_capacidades() missing'; end if;

  if not exists (
    select 1 from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id
    where r.codigo='entrenador' and rc.capacidad_codigo='rffm.results.read_assigned'
  ) then raise exception '101 contract: entrenador missing assigned RFFM read'; end if;
  if not exists (
    select 1 from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id
    where r.codigo='entrenador' and rc.capacidad_codigo='teams.roster.read_assigned'
  ) then raise exception '101 contract: entrenador missing roster capability'; end if;
  if exists (
    select 1 from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id
    where r.codigo='entrenador' and rc.capacidad_codigo in ('structure.manage','people.manage','equipment.manage','sponsors.manage')
  ) then raise exception '101 contract: entrenador received management capability'; end if;
  if not exists (
    select 1 from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id
    where r.codigo='club' and rc.capacidad_codigo='structure.manage'
  ) then raise exception '101 contract: club missing structure.manage'; end if;
  if not exists (
    select 1 from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id
    where r.codigo='administrador' and rc.capacidad_codigo='people.manage'
  ) then raise exception '101 contract: administrador missing people.manage'; end if;

  if pg_get_functiondef('private.can_read_rffm_equipo(uuid)'::regprocedure) not like '%has_capability%' then
    raise exception '101 contract: RFFM read authorization is not capability-based';
  end if;
  if pg_get_functiondef('public.puede_gestionar_rffm()'::regprocedure) not like '%rffm.config.manage%' then
    raise exception '101 contract: RFFM management is not capability-based';
  end if;
end $$;

rollback;
