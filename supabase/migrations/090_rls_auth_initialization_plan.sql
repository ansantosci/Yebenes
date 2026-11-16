-- 090_rls_auth_initialization_plan.sql
-- Supabase Advisor performance hardening.
-- Semantic-preserving rewrite: auth.uid() -> (select auth.uid()) in six SELECT policies.
-- No changes to roles, commands, business authorization or write policies.

begin;

drop policy if exists entrenador_disponibilidad_read_v90_1 on public.entrenador_disponibilidad;
create policy entrenador_disponibilidad_read_v90_1
on public.entrenador_disponibilidad
for select
to authenticated
using (
  private.has_any_role(array['administrador'::text, 'club'::text])
  or exists (
    select 1
    from public.entrenadores e
    join public.personas p on p.id = e.persona_id
    where e.id = entrenador_disponibilidad.entrenador_id
      and p.auth_user_id = (select auth.uid())
  )
);

drop policy if exists entrenador_disponibilidad_self_read on public.entrenador_disponibilidad;
create policy entrenador_disponibilidad_self_read
on public.entrenador_disponibilidad
for select
to authenticated
using (
  exists (
    select 1
    from public.entrenadores e
    join public.personas p on p.id = e.persona_id
    where e.id = entrenador_disponibilidad.entrenador_id
      and p.auth_user_id = (select auth.uid())
  )
);

drop policy if exists entrenador_formaciones_read on public.entrenador_formaciones;
create policy entrenador_formaciones_read
on public.entrenador_formaciones
for select
to authenticated
using (
  private.has_any_role(array['administrador'::text, 'club'::text])
  or exists (
    select 1
    from public.entrenadores e
    join public.personas p on p.id = e.persona_id
    where e.id = entrenador_formaciones.entrenador_id
      and p.auth_user_id = (select auth.uid())
  )
);

drop policy if exists entrenador_licencias_read on public.entrenador_licencias_rffm;
create policy entrenador_licencias_read
on public.entrenador_licencias_rffm
for select
to authenticated
using (
  private.has_any_role(array['administrador'::text, 'club'::text])
  or exists (
    select 1
    from public.entrenadores e
    join public.personas p on p.id = e.persona_id
    where e.id = entrenador_licencias_rffm.entrenador_id
      and p.auth_user_id = (select auth.uid())
  )
);

drop policy if exists entrenador_temporadas_self_read on public.entrenador_temporadas;
create policy entrenador_temporadas_self_read
on public.entrenador_temporadas
for select
to authenticated
using (
  exists (
    select 1
    from public.entrenadores e
    join public.personas p on p.id = e.persona_id
    where e.id = entrenador_temporadas.entrenador_id
      and p.auth_user_id = (select auth.uid())
  )
);

drop policy if exists horarios_equipo_coach_read on public.horarios_equipo;
create policy horarios_equipo_coach_read
on public.horarios_equipo
for select
to authenticated
using (
  private.has_any_role(array['administrador'::text, 'club'::text])
  or exists (
    select 1
    from public.asignaciones_entrenador_equipo a
    join public.entrenadores e on e.id = a.entrenador_id
    join public.personas p on p.id = e.persona_id
    where a.equipo_id = horarios_equipo.equipo_id
      and p.auth_user_id = (select auth.uid())
      and a.cancelada_at is null
      and a.fecha_desde <= current_date
      and (a.fecha_hasta is null or a.fecha_hasta >= current_date)
  )
);

commit;
