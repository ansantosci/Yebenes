-- 102: canonical temporal semantics for persona_roles / RBAC.
-- NULL fecha_desde = unknown/no lower bound. NULL fecha_hasta = no upper bound.

create or replace function private.persona_role_is_active(
  fecha_desde date,
  fecha_hasta date,
  fecha_referencia date default current_date
)
returns boolean
language sql
immutable
set search_path = pg_catalog, pg_temp
as $$
  select (fecha_desde is null or fecha_desde <= fecha_referencia)
     and (fecha_hasta is null or fecha_hasta >= fecha_referencia);
$$;

comment on function private.persona_role_is_active(date,date,date) is
'Canonical persona_roles validity: NULL fecha_desde means no known lower bound; NULL fecha_hasta means no upper bound.';

revoke all on function private.persona_role_is_active(date,date,date) from public, anon;
grant execute on function private.persona_role_is_active(date,date,date) to authenticated, service_role;

create or replace function private.has_capability(capability_code text)
returns boolean
language sql stable security definer
set search_path = public, private, pg_temp
as $$
  select exists (
    select 1
    from public.personas p
    join public.persona_roles pr on pr.persona_id=p.id
    join private.rol_capacidades rc on rc.rol_id=pr.rol_id
    where p.auth_user_id=(select auth.uid())
      and p.activo is true and pr.activo is true
      and private.persona_role_is_active(pr.fecha_desde, pr.fecha_hasta, current_date)
      and rc.capacidad_codigo=capability_code
  );
$$;
revoke all on function private.has_capability(text) from public, anon, authenticated;
grant execute on function private.has_capability(text) to authenticated, service_role;

create or replace function public.mis_capacidades()
returns table(rol_codigo text, capacidad_codigo text)
language sql stable security definer
set search_path = public, private, pg_temp
as $$
  select distinct r.codigo, rc.capacidad_codigo
  from public.personas p
  join public.persona_roles pr on pr.persona_id=p.id
  join public.roles r on r.id=pr.rol_id
  join private.rol_capacidades rc on rc.rol_id=r.id
  where p.auth_user_id=(select auth.uid())
    and p.activo is true and pr.activo is true
    and private.persona_role_is_active(pr.fecha_desde, pr.fecha_hasta, current_date)
  order by r.codigo,rc.capacidad_codigo;
$$;
revoke all on function public.mis_capacidades() from public, anon;
grant execute on function public.mis_capacidades() to authenticated, service_role;
