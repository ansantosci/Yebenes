-- 100: RFFM results authorization for coaches assigned to the requested team.
begin;

create or replace function private.can_read_rffm_equipo(target_equipo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select
    private.has_any_role(array['administrador'::text,'club'::text])
    or exists (
      select 1
      from public.asignaciones_entrenador_equipo a
      join public.entrenadores e on e.id = a.entrenador_id
      join public.personas p on p.id = e.persona_id
      where a.equipo_id = target_equipo_id
        and e.activo is true
        and p.activo is true
        and p.auth_user_id = (select auth.uid())
        and a.cancelada_at is null
        and a.fecha_desde <= current_date
        and (a.fecha_hasta is null or a.fecha_hasta >= current_date)
    );
$$;

revoke all on function private.can_read_rffm_equipo(uuid) from public, anon, authenticated;
grant execute on function private.can_read_rffm_equipo(uuid) to authenticated, service_role;

create or replace function public.puede_consultar_rffm_equipo(p_equipo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$ select private.can_read_rffm_equipo(p_equipo_id); $$;

create or replace function public.puede_gestionar_rffm()
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$ select private.has_any_role(array['administrador'::text,'club'::text]); $$;

revoke all on function public.puede_consultar_rffm_equipo(uuid) from public, anon;
revoke all on function public.puede_gestionar_rffm() from public, anon;
grant execute on function public.puede_consultar_rffm_equipo(uuid) to authenticated, service_role;
grant execute on function public.puede_gestionar_rffm() to authenticated, service_role;

drop policy if exists rffm_resultados_snapshots_club_read on public.rffm_resultados_snapshots;
drop policy if exists rffm_resultados_estado_club_read on public.rffm_resultados_estado;

create policy rffm_resultados_snapshots_authorized_read
on public.rffm_resultados_snapshots for select to authenticated
using (
  exists (
    select 1
    from public.equipo_integraciones_federacion i
    where i.id = rffm_resultados_snapshots.integracion_id
      and private.can_read_rffm_equipo(i.equipo_id)
  )
);

create policy rffm_resultados_estado_authorized_read
on public.rffm_resultados_estado for select to authenticated
using (
  exists (
    select 1
    from public.equipo_integraciones_federacion i
    where i.id = rffm_resultados_estado.integracion_id
      and private.can_read_rffm_equipo(i.equipo_id)
  )
);

commit;
