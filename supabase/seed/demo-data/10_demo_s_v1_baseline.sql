-- DEMO-S v1: deterministic, presentation-ready data.
-- It never creates Auth accounts and never assigns auth_user_id to a Persona.
-- Two synthetic players and one family are added for every active team.
begin;

insert into private.demo_datasets(id, version, scenario, metadata)
values (
  'DEMO-S',
  '1.0',
  'BASELINE',
  '{"purpose":"presentation-ready synthetic club data","identity_policy":"no Auth users; existing identities untouched"}'::jsonb
)
on conflict (id) do update
set version = excluded.version,
    scenario = excluded.scenario,
    loaded_at = now(),
    metadata = excluded.metadata;

-- One demonstrative family per active team.
with teams as (
  select e.codigo, row_number() over (order by e.codigo) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  where t.estado = 'activa'
)
insert into public.personas(id, nombre, primer_apellido, segundo_apellido, fecha_nacimiento, email_contacto, telefono, activo)
select private.demo_uuid('family:' || codigo),
       'Familia DEMO',
       codigo,
       null,
       date '1984-01-01' + n::integer,
       lower(codigo) || '.familia@demo.invalid',
       '611' || lpad(n::text, 6, '0'),
       true
from teams
on conflict (id) do update
set email_contacto = excluded.email_contacto,
    telefono = excluded.telefono,
    activo = true;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'personas', private.demo_uuid('family:' || e.codigo)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
where t.estado = 'activa'
on conflict do nothing;

-- Every family can use the same real forms as a club demonstration: phone and valid primary DNI.
with teams as (
  select e.codigo, row_number() over (order by e.codigo) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  where t.estado = 'activa'
), docs as (
  select codigo, 74000000 + n::integer as dni_number
  from teams
)
insert into public.documentos_identidad(id, persona_id, tipo, numero, pais_emisor, es_principal, fecha_desde, activo)
select private.demo_uuid('family-document:' || codigo),
       private.demo_uuid('family:' || codigo),
       'dni',
       lpad(dni_number::text, 8, '0') || substring('TRWAGMYFPDXBNJZSQVHLCKE' from (dni_number % 23) + 1 for 1),
       'ES', true, date '2026-07-01', true
from docs
on conflict (id) do update
set numero = excluded.numero,
    es_principal = true,
    fecha_hasta = null,
    activo = true;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'documentos_identidad', private.demo_uuid('family-document:' || e.codigo)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
where t.estado = 'activa'
on conflict do nothing;

-- Two players per team. Ages follow the configured category rule at the season reference point.
with teams as (
  select e.codigo,
         coalesce(r.anio_nacimiento_hasta, 2000) as birth_year
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  left join public.reglas_categoria_temporada r
    on r.temporada_id = e.temporada_id
   and r.categoria_id = e.categoria_id
   and r.activo
  where t.estado = 'activa'
), players as (
  select teams.*, g
  from teams
  cross join generate_series(1, 2) g
)
insert into public.personas(id, nombre, primer_apellido, segundo_apellido, fecha_nacimiento, email_contacto, activo)
select private.demo_uuid('player:' || codigo || ':' || g),
       'Jugador DEMO',
       codigo || ' ' || lpad(g::text, 2, '0'),
       null,
       make_date(birth_year, case when g = 1 then 3 else 9 end, case when g = 1 then 10 else 20 end),
       lower(codigo) || '.jugador' || g || '@demo.invalid',
       true
from players
on conflict (id) do update
set fecha_nacimiento = excluded.fecha_nacimiento,
    email_contacto = excluded.email_contacto,
    activo = true;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'personas', private.demo_uuid('player:' || e.codigo || ':' || g)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
where t.estado = 'activa'
on conflict do nothing;

-- Legal-age document coverage: all 14+ have DNI; under-14 alternates between with and without DNI.
with players as (
  select e.codigo, g, p.fecha_nacimiento, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  join public.personas p on p.id = private.demo_uuid('player:' || e.codigo || ':' || g)
  where t.estado = 'activa'
), docs as (
  select codigo, g, 75000000 + n::integer as dni_number
  from players
  where date '2026-09-01' >= (fecha_nacimiento + interval '14 years')::date
     or (date '2026-09-01' < (fecha_nacimiento + interval '14 years')::date and n % 2 = 0)
)
insert into public.documentos_identidad(id, persona_id, tipo, numero, pais_emisor, es_principal, fecha_desde, activo)
select private.demo_uuid('player-document:' || codigo || ':' || g),
       private.demo_uuid('player:' || codigo || ':' || g),
       'dni',
       lpad(dni_number::text, 8, '0') || substring('TRWAGMYFPDXBNJZSQVHLCKE' from (dni_number % 23) + 1 for 1),
       'ES', true, date '2026-07-01', true
from docs
on conflict (id) do update
set numero = excluded.numero,
    es_principal = true,
    fecha_hasta = null,
    activo = true;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'documentos_identidad', private.demo_uuid('player-document:' || codigo || ':' || g)
from (
  select e.codigo, g, p.fecha_nacimiento, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  join public.personas p on p.id = private.demo_uuid('player:' || e.codigo || ':' || g)
  where t.estado = 'activa'
) players
where date '2026-09-01' >= (fecha_nacimiento + interval '14 years')::date
   or (date '2026-09-01' < (fecha_nacimiento + interval '14 years')::date and n % 2 = 0)
on conflict do nothing;

insert into public.jugadores(id, persona_id, activo, fecha_alta)
select private.demo_uuid('player-facet:' || e.codigo || ':' || g),
       private.demo_uuid('player:' || e.codigo || ':' || g),
       true,
       date '2026-07-01'
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
where t.estado = 'activa'
on conflict (id) do update
set persona_id = excluded.persona_id,
    activo = true,
    fecha_baja = null;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'jugadores', private.demo_uuid('player-facet:' || e.codigo || ':' || g)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
where t.estado = 'activa'
on conflict do nothing;

-- Representation exists before inscriptions for all minors.
insert into public.representaciones_jugador(id, jugador_id, representante_persona_id, fecha_desde, motivo_alta)
select private.demo_uuid('representation:' || e.codigo || ':' || g),
       private.demo_uuid('player-facet:' || e.codigo || ':' || g),
       private.demo_uuid('family:' || e.codigo),
       date '2026-07-01',
       'Representacion DEMO'
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
join public.personas p on p.id = private.demo_uuid('player:' || e.codigo || ':' || g)
where t.estado = 'activa'
  and date '2026-09-01' < (p.fecha_nacimiento + interval '18 years')::date
on conflict (id) do update set fecha_hasta = null;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'representaciones_jugador', private.demo_uuid('representation:' || e.codigo || ':' || g)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
join public.personas p on p.id = private.demo_uuid('player:' || e.codigo || ':' || g)
where t.estado = 'activa'
  and date '2026-09-01' < (p.fecha_nacimiento + interval '18 years')::date
on conflict do nothing;

-- Varied inscription states make the dashboard and detail views meaningful in a club demonstration.
insert into public.inscripciones(id, jugador_id, temporada_id, categoria_id, fecha_solicitud, estado, observaciones)
select private.demo_uuid('inscription:' || e.codigo || ':' || g),
       private.demo_uuid('player-facet:' || e.codigo || ':' || g),
       e.temporada_id, e.categoria_id, date '2026-09-01',
       (array['pendiente_revision_inicial', 'datos_validados', 'documentacion_validada', 'lista_para_federar', 'ficha_tramitada'])[((row_number() over (order by e.codigo, g) - 1) % 5) + 1],
       'Caso DEMO v1'
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
where t.estado = 'activa'
on conflict (id) do update
set estado = excluded.estado,
    observaciones = excluded.observaciones;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'inscripciones', private.demo_uuid('inscription:' || e.codigo || ':' || g)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
where t.estado = 'activa'
on conflict do nothing;

insert into public.asignaciones_jugador_equipo(id, inscripcion_id, equipo_id, fecha_desde, motivo_cambio)
select private.demo_uuid('player-team:' || e.codigo || ':' || g),
       private.demo_uuid('inscription:' || e.codigo || ':' || g),
       e.id, date '2026-09-01', 'Asignacion DEMO'
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
where t.estado = 'activa'
on conflict (id) do update
set equipo_id = excluded.equipo_id,
    fecha_hasta = null;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'asignaciones_jugador_equipo', private.demo_uuid('player-team:' || e.codigo || ':' || g)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
cross join generate_series(1, 2) g
where t.estado = 'activa'
on conflict do nothing;

-- Tutor roles permit representative data to be displayed without introducing new logins.
insert into public.persona_roles(id, persona_id, rol_id, fecha_desde, activo)
select private.demo_uuid('family-role:' || e.codigo),
       private.demo_uuid('family:' || e.codigo),
       r.id, date '2026-07-01', true
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
join public.roles r on r.codigo = 'tutor'
where t.estado = 'activa'
on conflict (id) do update set activo = true, fecha_hasta = null;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'persona_roles', private.demo_uuid('family-role:' || e.codigo)
from public.equipos e
join public.temporadas t on t.id = e.temporada_id
where t.estado = 'activa'
on conflict do nothing;

-- Health and documentation examples cover current, expiring, expired and pending states.
with players as (
  select e.codigo, g, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  where t.estado = 'activa'
  order by e.codigo, g
  limit 10
)
insert into public.reconocimientos_medicos(id, jugador_id, persona_id, fecha_reconocimiento, fecha_valido_hasta, centro_medico, observaciones)
select private.demo_uuid('medical:' || codigo || ':' || g),
       private.demo_uuid('player-facet:' || codigo || ':' || g),
       private.demo_uuid('player:' || codigo || ':' || g),
       current_date - 400,
       case n when 1 then current_date + 200 when 2 then current_date + 80 when 3 then current_date + 20 when 4 then current_date - 10 else current_date + 300 end,
       'Centro Medico DEMO', 'Caso DEMO v1'
from players
where n <= 5
on conflict (id) do update set fecha_valido_hasta = excluded.fecha_valido_hasta;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'reconocimientos_medicos', private.demo_uuid('medical:' || codigo || ':' || g)
from (
  select e.codigo, g, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  where t.estado = 'activa'
) players
where n <= 5
on conflict do nothing;

with players as (
  select e.codigo, g, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  where t.estado = 'activa'
  order by e.codigo, g
  limit 10
)
insert into public.citas_reconocimiento_medico(id, jugador_id, persona_id, fecha_hora, lugar, direccion, indicaciones, estado)
select private.demo_uuid('medical-appointment:' || codigo || ':' || g),
       private.demo_uuid('player-facet:' || codigo || ':' || g),
       private.demo_uuid('player:' || codigo || ':' || g),
       case n when 6 then now() + interval '10 days' when 7 then now() - interval '2 days' when 8 then now() + interval '15 days' else now() - interval '5 days' end,
       'Centro Medico DEMO', 'Calle DEMO 1', 'Caso DEMO v1',
       case n when 8 then 'cancelada' when 9 then 'no_asiste' else 'programada' end
from players
where n between 6 and 9
on conflict (id) do update set fecha_hora = excluded.fecha_hora, estado = excluded.estado;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'citas_reconocimiento_medico', private.demo_uuid('medical-appointment:' || codigo || ':' || g)
from (
  select e.codigo, g, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  where t.estado = 'activa'
) players
where n between 6 and 9
on conflict do nothing;

with players as (
  select e.codigo, g, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  where t.estado = 'activa'
  order by e.codigo, g
  limit 6
)
insert into public.requisitos_federativos_inscripcion(id, inscripcion_id, codigo, nombre, obligatorio, requiere_archivo, estado, motivo_rechazo)
select private.demo_uuid('requirement:' || codigo || ':' || g),
       private.demo_uuid('inscription:' || codigo || ':' || g),
       'DEMO_DOC', 'Documento DEMO', true, true,
       (array['pendiente', 'aportado', 'validado', 'rechazado', 'nueva_version_solicitada', 'declarado_realizado'])[n],
       case when n = 4 then 'Documento ilegible en el caso DEMO' end
from players
on conflict (id) do update
set estado = excluded.estado,
    motivo_rechazo = excluded.motivo_rechazo;

insert into private.demo_dataset_entities(dataset_id, table_name, entity_id)
select 'DEMO-S', 'requisitos_federativos_inscripcion', private.demo_uuid('requirement:' || codigo || ':' || g)
from (
  select e.codigo, g, row_number() over (order by e.codigo, g) as n
  from public.equipos e
  join public.temporadas t on t.id = e.temporada_id
  cross join generate_series(1, 2) g
  where t.estado = 'activa'
) players
where n <= 6
on conflict do nothing;

update private.demo_datasets
set scenario = 'BASELINE', loaded_at = now()
where id = 'DEMO-S';

commit;
