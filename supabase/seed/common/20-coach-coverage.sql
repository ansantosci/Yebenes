-- Canonical coaching coverage validation/augmentation contract.
-- Baselines must provide enough coach facets; this script adds deterministic secondary assignments
-- using existing active coaches, while never replacing an existing principal.
begin;

-- Ensure every active team has at least two effective active coach assignments.
with active_teams as (
  select e.id as team_id, e.codigo as team_code,
         row_number() over(order by e.codigo,e.id) as team_rn
  from public.equipos e
  join public.temporadas t on t.id=e.temporada_id
  where t.estado='activa' and e.activo
), active_coaches as (
  select c.id as coach_id, row_number() over(order by c.id) as coach_rn
  from public.entrenadores c
  where c.activo
), missing as (
  select t.team_id,t.team_code,t.team_rn, greatest(0,2-count(distinct a.entrenador_id)) as missing_count
  from active_teams t
  left join public.asignaciones_entrenador_equipo a
    on a.equipo_id=t.team_id and a.cancelada_at is null
   and a.fecha_desde<=date '2027-06-30'
   and (a.fecha_hasta is null or a.fecha_hasta>=date '2026-09-01')
  group by t.team_id,t.team_code,t.team_rn
), slots as (
  select m.team_id,m.team_code,m.team_rn,g as slot
  from missing m
  cross join lateral generate_series(1,m.missing_count) g
), candidates as (
  select s.team_id,s.team_code,s.team_rn,s.slot,c.coach_id,
         row_number() over(partition by s.team_id,s.slot order by c.coach_rn) as candidate_rn
  from slots s
  cross join active_coaches c
  where not exists (
    select 1 from public.asignaciones_entrenador_equipo a
    where a.equipo_id=s.team_id and a.entrenador_id=c.coach_id
      and a.cancelada_at is null
      and a.fecha_desde<=date '2027-06-30'
      and (a.fecha_hasta is null or a.fecha_hasta>=date '2026-09-01')
  )
), chosen as (
  select team_id,team_code,team_rn,slot,coach_id
  from candidates
  where candidate_rn=slot
)
insert into public.asignaciones_entrenador_equipo(id,entrenador_id,equipo_id,rol,funcion,fecha_desde)
select md5('canonical-coach-cover:'||ch.team_id::text||':'||ch.slot)::uuid,
       ch.coach_id,ch.team_id,'Entrenador','second',date '2026-09-01'
from chosen ch
on conflict(id) do update
set entrenador_id=excluded.entrenador_id,
    equipo_id=excluded.equipo_id,
    rol=excluded.rol,
    funcion=excluded.funcion,
    fecha_desde=excluded.fecha_desde,
    fecha_hasta=null,
    cancelada_at=null;

do $$
declare uncovered integer; dual integer; multiteam integer; unassigned integer;
begin
 select count(*) into uncovered from (
   select e.id from public.equipos e join public.temporadas t on t.id=e.temporada_id
   left join public.asignaciones_entrenador_equipo a on a.equipo_id=e.id and a.cancelada_at is null
     and a.fecha_desde<=date '2027-06-30' and (a.fecha_hasta is null or a.fecha_hasta>=date '2026-09-01')
   where t.estado='activa' and e.activo group by e.id having count(a.id)<2
 )x;
 if uncovered<>0 then raise exception 'Coach coverage: % active teams have fewer than 2 effective coaches',uncovered; end if;
 select count(distinct c.id) into dual from public.entrenadores c join public.jugadores j on j.persona_id=c.persona_id where c.activo and j.activo;
 if dual<4 then raise exception 'Coach coverage: expected at least 4 coach-player cases, got %',dual; end if;
 select count(*) into multiteam from (select entrenador_id from public.asignaciones_entrenador_equipo where cancelada_at is null group by entrenador_id having count(distinct equipo_id)>1)x;
 if multiteam<1 then raise exception 'Coach coverage: expected at least one multi-team coach'; end if;
 select count(*) into unassigned from public.entrenadores c where c.activo and not exists(select 1 from public.asignaciones_entrenador_equipo a where a.entrenador_id=c.id and a.cancelada_at is null);
 if unassigned<1 then raise exception 'Coach coverage: expected at least one active unassigned coach'; end if;
end $$;
commit;
