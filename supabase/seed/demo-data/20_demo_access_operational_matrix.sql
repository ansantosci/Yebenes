-- DEMO-S operational bindings for permanent DEMO-ACCESS identities.
-- The identities/facets stay outside DEMO-S; only these seasonal relations are
-- registered and reset with the dataset. If DEMO-ACCESS has not been provisioned
-- yet, this script is intentionally a no-op so ordinary DEMO-S refreshes remain safe.
begin;

do $$
declare
  identity_count integer;
begin
  select count(*) into identity_count from private.demo_access_identities;
  if identity_count = 0 then
    raise notice 'DEMO-ACCESS not provisioned: skipping operational bindings.';
  elsif identity_count <> 7 then
    raise exception 'DEMO-ACCESS contract failed: expected 7 identities, found %', identity_count;
  end if;
end $$;

-- The minor-player inscription is guarded by validar_tutor_menor_inscripcion,
-- so its legal representative must be active before the inscription is loaded.
-- This relation is operational DEMO-S data, while the tutor identity itself remains
-- a permanent DEMO-ACCESS identity.
insert into public.representaciones_jugador(id, jugador_id, representante_persona_id, fecha_desde, motivo_alta)
select private.demo_uuid('access-representation:tutor'),
       private.demo_uuid('access-player:minor_player'),
       private.demo_access_persona_id('tutor'),
       date '2026-07-01', 'Representacion DEMO-ACCESS'
where exists (select 1 from private.demo_access_identities where key = 'tutor')
on conflict (id) do update set fecha_hasta = null;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'representaciones_jugador', private.demo_uuid('access-representation:tutor')
where exists (select 1 from private.demo_access_identities where key = 'tutor')
on conflict do nothing;

-- Four player-capable login profiles receive an active synthetic inscription.
-- Teams are selected deterministically from the active season; the accounts can
-- then exercise player, family and club flows against the same DEMO-S data model.
with target_profiles(key, category_code, team_position) as (values
  ('minor_player', 'CAD', 1),
  ('coach_player', 'SEN', 1),
  ('multiprofile', 'SEN', 2),
  ('adult_player', 'SEN', 3)
), target_teams as (
  select e.id as equipo_id, e.temporada_id, e.categoria_id, c.codigo as category_code,
         row_number() over (partition by c.codigo order by e.codigo) as team_position
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  join public.categorias c on c.id = e.categoria_id
  where t.estado = 'activa'
), selected as (
  select p.key, i.persona_id, t.equipo_id, t.temporada_id, t.categoria_id
  from target_profiles p
  join private.demo_access_identities i on i.key = p.key
  join target_teams t on t.category_code = p.category_code and t.team_position = p.team_position
)
insert into public.inscripciones(id, jugador_id, temporada_id, categoria_id, fecha_solicitud, estado, observaciones)
select private.demo_uuid('access-inscription:' || selected.key),
       private.demo_uuid('access-player:' || selected.key),
       selected.temporada_id, selected.categoria_id, date '2026-09-01',
       case selected.key when 'minor_player' then 'pendiente_revision_inicial'
                         when 'adult_player' then 'documentacion_validada'
                         when 'coach_player' then 'lista_para_federar'
                         else 'ficha_tramitada' end,
       'Caso DEMO-ACCESS'
from selected
on conflict (id) do update
set jugador_id = excluded.jugador_id,
    temporada_id = excluded.temporada_id,
    categoria_id = excluded.categoria_id,
    estado = excluded.estado,
    observaciones = excluded.observaciones;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'inscripciones', private.demo_uuid('access-inscription:' || key)
from private.demo_access_identities
where key in ('minor_player', 'adult_player', 'coach_player', 'multiprofile')
on conflict do nothing;

with target_profiles(key, category_code, team_position) as (values
  ('minor_player', 'CAD', 1),
  ('coach_player', 'SEN', 1),
  ('multiprofile', 'SEN', 2),
  ('adult_player', 'SEN', 3)
), target_teams as (
  select e.id as equipo_id, c.codigo as category_code,
         row_number() over (partition by c.codigo order by e.codigo) as team_position
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  join public.categorias c on c.id = e.categoria_id
  where t.estado = 'activa'
)
insert into public.asignaciones_jugador_equipo(id, inscripcion_id, equipo_id, fecha_desde, motivo_cambio)
select private.demo_uuid('access-player-team:' || p.key),
       private.demo_uuid('access-inscription:' || p.key),
       t.equipo_id, date '2026-09-01', 'Asignacion DEMO-ACCESS'
from target_profiles p
join target_teams t on t.category_code = p.category_code and t.team_position = p.team_position
on conflict (id) do update
set equipo_id = excluded.equipo_id,
    fecha_hasta = null;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'asignaciones_jugador_equipo', private.demo_uuid('access-player-team:' || key)
from private.demo_access_identities
where key in ('minor_player', 'adult_player', 'coach_player', 'multiprofile')
on conflict do nothing;

-- Coach-capable profiles receive visible, deterministic seasonal assignments.
with target_profiles(key, position) as (values
  ('coach', 1), ('coach_player', 2), ('multiprofile', 3)
), active_season as (
  select id from public.temporadas where estado = 'activa' order by fecha_inicio desc limit 1
)
insert into public.entrenador_temporadas(id, entrenador_id, temporada_id, estado, disponibilidad_confirmada_at)
select private.demo_uuid('access-coach-season:' || p.key),
       private.demo_uuid('access-coach:' || p.key), active_season.id, 'activo', now()
from target_profiles p cross join active_season
on conflict (id) do update
set estado = excluded.estado,
    disponibilidad_confirmada_at = excluded.disponibilidad_confirmada_at;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'entrenador_temporadas', private.demo_uuid('access-coach-season:' || key)
from private.demo_access_identities
where key in ('coach', 'coach_player', 'multiprofile')
on conflict do nothing;

with target_profiles(key, category_code, team_position) as (values
  ('coach', 'ALE', 1),
  ('coach_player', 'SEN', 1),
  ('multiprofile', 'SEN', 2)
), target_teams as (
  select e.id as equipo_id, c.codigo as category_code,
         row_number() over (partition by c.codigo order by e.codigo) as team_position
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  join public.categorias c on c.id = e.categoria_id
  where t.estado = 'activa'
)
insert into public.asignaciones_entrenador_equipo(id, entrenador_id, equipo_id, rol, funcion, fecha_desde)
select private.demo_uuid('access-coach-team:' || p.key),
       private.demo_uuid('access-coach:' || p.key),
       t.equipo_id, 'Entrenador',
       -- DEMO-S teams already have a principal. The access profiles exercise
       -- complementary coach roles without competing with baseline data.
       case p.key when 'coach_player' then 'fitness' when 'multiprofile' then 'second' else 'second' end,
       date '2026-09-01'
from target_profiles p
join target_teams t on t.category_code = p.category_code and t.team_position = p.team_position
on conflict (id) do update
set equipo_id = excluded.equipo_id,
    funcion = excluded.funcion,
    fecha_hasta = null,
    cancelada_at = null;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'asignaciones_entrenador_equipo', private.demo_uuid('access-coach-team:' || key)
from private.demo_access_identities
where key in ('coach', 'coach_player', 'multiprofile')
on conflict do nothing;

commit;
