-- 068 - Fix active sibling group duplication introduced in 067.
-- A player sharing a representative with itself was emitted once as automatic and
-- once as propio. Deduplicate by jugador_id before assigning sibling positions.
begin;

create or replace function private.economia_hermanos_activos(p_persona uuid,p_temporada uuid)
returns table(persona_id uuid,jugador_id uuid,primera_asignacion date,fuente text)
language sql stable security definer set search_path='' as $$
with me as (
 select j.id jugador_id from public.jugadores j where j.persona_id=p_persona
), active as (
 select distinct j.persona_id,j.id jugador_id,min(a.fecha_desde) over(partition by j.id) primera_asignacion
 from public.jugadores j
 join public.inscripciones i on i.jugador_id=j.id and i.temporada_id=p_temporada and i.estado<>'cancelada'
 join public.asignaciones_jugador_equipo a on a.inscripcion_id=i.id and a.fecha_desde<=current_date and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
 join public.persona_participaciones_temporada pt on pt.persona_id=j.persona_id and pt.temporada_id=p_temporada and pt.faceta='jugador' and pt.estado='aceptada'
), auto_ids as (
 select distinct a2.jugador_id
 from me m
 join public.representaciones_jugador r1 on r1.jugador_id=m.jugador_id
   and r1.fecha_desde<=current_date and (r1.fecha_hasta is null or r1.fecha_hasta>=current_date)
 join public.representaciones_jugador r2 on r2.representante_persona_id=r1.representante_persona_id
   and r2.fecha_desde<=current_date and (r2.fecha_hasta is null or r2.fecha_hasta>=current_date)
 join active a2 on a2.jugador_id=r2.jugador_id
), manual_ids as (
 with recursive links(a,b) as (
   select jugador_a_id,jugador_b_id from public.economia_hermanos_vinculos_manuales where temporada_id=p_temporada and activo
   union all
   select jugador_b_id,jugador_a_id from public.economia_hermanos_vinculos_manuales where temporada_id=p_temporada and activo
 ), reach(jid) as (
   select jugador_id from me
   union
   select l.b from reach r join links l on l.a=r.jid
 )
 select jid from reach
), candidates as (
 select jugador_id,'automatico'::text fuente from auto_ids
 union all
 select jid,'manual'::text from manual_ids
 union all
 select a.jugador_id,'propio'::text from active a where a.persona_id=p_persona
), dedup as (
 select jugador_id,
        case
          when bool_or(fuente='manual') then 'manual'
          when bool_or(fuente='automatico') then 'automatico'
          else 'propio'
        end fuente
 from candidates
 group by jugador_id
)
select a.persona_id,a.jugador_id,a.primera_asignacion,d.fuente
from dedup d
join active a on a.jugador_id=d.jugador_id
$$;

revoke all on function private.economia_hermanos_activos(uuid,uuid) from public,anon,authenticated;
grant execute on function private.economia_hermanos_activos(uuid,uuid) to service_role;

commit;
