-- 103: minimal identity projection for players assigned to the authenticated coach.
-- Purpose: hydrate player names for players.read_assigned without widening RLS on public.personas.
begin;

create or replace function public.identidad_jugadores_asignados(p_jugador_ids uuid[])
returns table(
  jugador_id uuid,
  persona_id uuid,
  nombre text,
  primer_apellido text,
  segundo_apellido text
)
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select distinct j.id, p.id, p.nombre, p.primer_apellido, p.segundo_apellido
  from public.jugadores j
  join public.personas p on p.id = j.persona_id
  join public.inscripciones i on i.jugador_id = j.id
  join public.asignaciones_jugador_equipo aje on aje.inscripcion_id = i.id
  where j.id = any(coalesce(p_jugador_ids, array[]::uuid[]))
    and j.activo is true
    and p.activo is true
    and private.has_capability('players.read_assigned')
    and aje.fecha_desde <= current_date
    and (aje.fecha_hasta is null or aje.fecha_hasta >= current_date)
    and exists (
      select 1
      from public.asignaciones_entrenador_equipo aee
      join public.entrenadores e on e.id = aee.entrenador_id
      join public.personas ep on ep.id = e.persona_id
      where aee.equipo_id = aje.equipo_id
        and e.activo is true
        and ep.activo is true
        and ep.auth_user_id = (select auth.uid())
        and aee.cancelada_at is null
        and aee.fecha_desde <= current_date
        and (aee.fecha_hasta is null or aee.fecha_hasta >= current_date)
    );
$$;

revoke all on function public.identidad_jugadores_asignados(uuid[]) from public, anon;
grant execute on function public.identidad_jugadores_asignados(uuid[]) to authenticated, service_role;

commit;
