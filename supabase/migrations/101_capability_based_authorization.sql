-- 101: canonical capability-based authorization (RBAC).
-- Roles remain identity/profile assignments; capabilities become the stable authorization API.
begin;

create table if not exists private.capacidades (
  codigo text primary key,
  nombre text not null,
  descripcion text,
  created_at timestamptz not null default now()
);

create table if not exists private.rol_capacidades (
  rol_id uuid not null references public.roles(id) on delete cascade,
  capacidad_codigo text not null references private.capacidades(codigo) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (rol_id, capacidad_codigo)
);

revoke all on table private.capacidades from public, anon, authenticated;
revoke all on table private.rol_capacidades from public, anon, authenticated;
grant select, insert, update, delete on table private.capacidades to service_role;
grant select, insert, update, delete on table private.rol_capacidades to service_role;

insert into private.capacidades(codigo,nombre,descripcion) values
 ('players.read_all','Consultar todas las fichas','Consulta administrativa de jugadores del club.'),
 ('players.read_assigned','Consultar jugadores asignados','Consulta de jugadores de los equipos asignados al entrenador.'),
 ('players.manage','Gestionar fichas','Gestión administrativa de fichas e inscripciones.'),
 ('medical.read_all','Consultar RRMM del club','Consulta de reconocimientos médicos del club.'),
 ('medical.read_assigned','Consultar RRMM asignados','Consulta de RRMM de jugadores de equipos asignados.'),
 ('medical.manage','Gestionar RRMM','Gestión de citas y reconocimientos médicos.'),
 ('coaches.manage','Gestionar entrenadores','Gestión de entrenadores y sus asignaciones.'),
 ('structure.manage','Gestionar estructura','Gestión de temporadas, categorías, equipos e integraciones.'),
 ('rffm.results.read_all','Consultar resultados RFFM del club','Consulta de resultados de todos los equipos.'),
 ('rffm.results.read_assigned','Consultar resultados RFFM asignados','Consulta de resultados de equipos asignados.'),
 ('rffm.results.update_all','Actualizar resultados RFFM del club','Actualización de resultados de todos los equipos.'),
 ('rffm.results.update_assigned','Actualizar resultados RFFM asignados','Actualización de resultados de equipos asignados.'),
 ('rffm.config.manage','Gestionar configuración RFFM','Gestión y validación de parámetros RFFM.'),
 ('people.manage','Gestionar personas','Gestión de personas, accesos y perfiles.'),
 ('equipment.manage','Gestionar equipaciones','Gestión logística y económica de equipaciones.'),
 ('sponsors.manage','Gestionar patrocinadores','Gestión de patrocinadores e identidad visual.'),
 ('profile.read','Consultar perfil propio','Acceso al perfil propio.'),
 ('teams.roster.read_assigned','Consultar plantillas asignadas','Base para la experiencia Plantillas del entrenador.')
on conflict (codigo) do update set nombre=excluded.nombre, descripcion=excluded.descripcion;

-- Rebuild the canonical matrix deterministically for the roles managed by the application.
delete from private.rol_capacidades rc
using public.roles r
where r.id=rc.rol_id and r.codigo in ('administrador','club','entrenador','tutor','jugador');

with matrix(rol_codigo, capacidad_codigo) as (values
 ('administrador','players.read_all'),('administrador','players.manage'),('administrador','medical.read_all'),('administrador','medical.manage'),
 ('administrador','coaches.manage'),('administrador','structure.manage'),('administrador','rffm.results.read_all'),('administrador','rffm.results.update_all'),
 ('administrador','rffm.config.manage'),('administrador','people.manage'),('administrador','equipment.manage'),('administrador','sponsors.manage'),('administrador','profile.read'),
 ('club','players.read_all'),('club','players.manage'),('club','medical.read_all'),('club','medical.manage'),('club','coaches.manage'),('club','structure.manage'),
 ('club','rffm.results.read_all'),('club','rffm.results.update_all'),('club','rffm.config.manage'),('club','equipment.manage'),('club','sponsors.manage'),('club','profile.read'),
 ('entrenador','players.read_assigned'),('entrenador','medical.read_assigned'),('entrenador','rffm.results.read_assigned'),
 ('entrenador','rffm.results.update_assigned'),('entrenador','teams.roster.read_assigned'),('entrenador','profile.read'),
 ('tutor','profile.read'),('jugador','profile.read')
)
insert into private.rol_capacidades(rol_id,capacidad_codigo)
select r.id,m.capacidad_codigo from matrix m join public.roles r on r.codigo=m.rol_codigo
on conflict do nothing;

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
      and pr.fecha_desde<=current_date
      and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
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
    and pr.fecha_desde<=current_date
    and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
  order by r.codigo,rc.capacidad_codigo;
$$;
revoke all on function public.mis_capacidades() from public, anon;
grant execute on function public.mis_capacidades() to authenticated, service_role;

-- Evolve RFFM authorization to consume the same capability matrix.
create or replace function private.can_read_rffm_equipo(target_equipo_id uuid)
returns boolean
language sql stable security definer
set search_path = public, private, pg_temp
as $$
  select private.has_capability('rffm.results.read_all')
    or (
      private.has_capability('rffm.results.read_assigned')
      and exists (
        select 1
        from public.asignaciones_entrenador_equipo a
        join public.entrenadores e on e.id=a.entrenador_id
        join public.personas p on p.id=e.persona_id
        where a.equipo_id=target_equipo_id
          and e.activo is true and p.activo is true
          and p.auth_user_id=(select auth.uid())
          and a.cancelada_at is null
          and a.fecha_desde<=current_date
          and (a.fecha_hasta is null or a.fecha_hasta>=current_date)
      )
    );
$$;

create or replace function public.puede_gestionar_rffm()
returns boolean
language sql stable security definer
set search_path = public, private, pg_temp
as $$ select private.has_capability('rffm.config.manage'); $$;

commit;
