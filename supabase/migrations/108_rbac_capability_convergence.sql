-- 108: converge remaining targeted authorization paths on capabilities.
-- Roles remain identity/context; capabilities are the authorization API.
begin;

create or replace function private.can_read_equipo_dorsales(target_equipo_id uuid)
returns boolean
language sql stable security definer
set search_path = public, private, pg_temp
as $$
  select private.has_capability('equipment.manage')
    or exists (
      select 1
      from public.asignaciones_entrenador_equipo a
      join public.entrenadores e on e.id=a.entrenador_id
      join public.personas p on p.id=e.persona_id
      where a.equipo_id=target_equipo_id
        and e.activo is true
        and p.activo is true
        and p.auth_user_id=(select auth.uid())
        and a.cancelada_at is null
        and a.fecha_desde<=current_date
        and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
    );
$$;

revoke all on function private.can_read_equipo_dorsales(uuid) from public, anon;
grant execute on function private.can_read_equipo_dorsales(uuid) to authenticated, service_role;

commit;
