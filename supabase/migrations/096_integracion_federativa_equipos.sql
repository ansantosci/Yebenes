-- 096_integracion_federativa_equipos.sql
-- Configuracion federativa externa por equipo/temporada sin acoplar public.equipos a RFFM.

begin;

create table if not exists public.equipo_integraciones_federacion (
  id uuid primary key default gen_random_uuid(),
  equipo_id uuid not null references public.equipos(id) on delete cascade,
  proveedor text not null default 'RFFM',
  competition_id text not null,
  group_id text not null,
  game_type text not null,
  external_team_id text null,
  config jsonb not null default '{}'::jsonb,
  activo boolean not null default true,
  ultima_validacion_at timestamptz null,
  ultima_validacion_ok boolean null,
  ultima_validacion_mensaje text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint equipo_integraciones_federacion_proveedor_chk
    check (proveedor ~ '^[A-Z0-9_]{2,32}$'),
  constraint equipo_integraciones_federacion_competition_chk
    check (length(btrim(competition_id)) between 1 and 64),
  constraint equipo_integraciones_federacion_group_chk
    check (length(btrim(group_id)) between 1 and 64),
  constraint equipo_integraciones_federacion_game_type_chk
    check (length(btrim(game_type)) between 1 and 32),
  constraint equipo_integraciones_federacion_external_team_chk
    check (external_team_id is null or length(btrim(external_team_id)) between 1 and 64),
  constraint equipo_integraciones_federacion_config_object_chk
    check (jsonb_typeof(config) = 'object'),
  constraint equipo_integraciones_federacion_equipo_proveedor_uq
    unique (equipo_id, proveedor)
);

comment on table public.equipo_integraciones_federacion is
  'Configuracion tecnica de integraciones federativas por equipo. El equipo/temporada de Yebenes es la identidad canonica; no se duplican nombre, categoria ni temporada.';
comment on column public.equipo_integraciones_federacion.competition_id is 'Identificador externo de competicion (RFFM: parametro competicion).';
comment on column public.equipo_integraciones_federacion.group_id is 'Identificador externo de grupo (RFFM: parametro grupo).';
comment on column public.equipo_integraciones_federacion.game_type is 'Tipo de juego externo (RFFM: parametro tipojuego).';
comment on column public.equipo_integraciones_federacion.external_team_id is 'Identificador externo del equipo, opcional; se usa como evidencia preferente cuando el proveedor lo expone de forma estable.';
comment on column public.equipo_integraciones_federacion.config is 'Parametros tecnicos adicionales no sensibles. No almacenar secretos ni URLs arbitrarias.';

create index if not exists equipo_integraciones_federacion_proveedor_activo_idx
  on public.equipo_integraciones_federacion(proveedor, activo)
  where activo;

create trigger equipo_integraciones_federacion_updated_at
before update on public.equipo_integraciones_federacion
for each row execute function public.set_updated_at();

alter table public.equipo_integraciones_federacion enable row level security;

-- Informacion deportiva/federativa no sensible: lectura para usuarios autenticados.
create policy equipo_integraciones_federacion_read
on public.equipo_integraciones_federacion
for select to authenticated
using (true);

-- Mutacion exclusivamente Club/Admin. Policies separadas para evitar Multiple Permissive Policies.
create policy equipo_integraciones_federacion_insert
on public.equipo_integraciones_federacion
for insert to authenticated
with check ((select private.has_any_role(array['administrador','club'])));

create policy equipo_integraciones_federacion_update
on public.equipo_integraciones_federacion
for update to authenticated
using ((select private.has_any_role(array['administrador','club'])))
with check ((select private.has_any_role(array['administrador','club'])));

create policy equipo_integraciones_federacion_delete
on public.equipo_integraciones_federacion
for delete to authenticated
using ((select private.has_any_role(array['administrador','club'])));

revoke all on table public.equipo_integraciones_federacion from public, anon;
grant select, insert, update, delete on table public.equipo_integraciones_federacion to authenticated;
grant all on table public.equipo_integraciones_federacion to service_role;

commit;
