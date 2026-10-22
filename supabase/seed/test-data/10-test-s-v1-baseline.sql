-- TEST-S v1 BASELINE: deterministic synthetic dataset.
-- 46 players (2/team), 23 tutors, 12 coaches (2 are also senior players), 23 team schedules.
begin;
insert into private.test_datasets(id,version,scenario,metadata) values('TEST-S','1','BASELINE','{"purpose":"small reproducible functional dataset"}')
on conflict(id) do update set version=excluded.version,scenario=excluded.scenario,loaded_at=now(),metadata=excluded.metadata;

-- Team schedules: deterministic and deliberately varied.
insert into public.horarios_equipo(id,equipo_id,dia_semana,hora_inicio,hora_fin,activo)
select private.test_uuid('schedule:'||e.codigo), e.id, 2 + (row_number() over(order by e.codigo)::int % 3),
       time '18:00' + ((row_number() over(order by e.codigo)::int % 3) * interval '30 minutes'),
       time '19:30' + ((row_number() over(order by e.codigo)::int % 3) * interval '30 minutes'), true
from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa'
on conflict(id) do update set dia_semana=excluded.dia_semana,hora_inicio=excluded.hora_inicio,hora_fin=excluded.hora_fin,activo=true;
insert into private.test_dataset_entities select 'TEST-S','horarios_equipo',private.test_uuid('schedule:'||e.codigo),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa' on conflict do nothing;

-- Economic configuration is shared TEST-BASE/master state. Reuse the existing row per season/team
-- instead of creating a TEST-S-owned duplicate. RESET must never delete these rows.
insert into public.configuracion_economica_equipo(id,temporada_id,equipo_id,importe_inscripcion,admite_fraccionamiento,requiere_pago_ficha,observaciones)
select private.test_uuid('econ-config:'||e.codigo),e.temporada_id,e.id,120 + (row_number() over(order by e.codigo)%4)*30,true,true,'TEST-S v1'
from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa'
on conflict(temporada_id,equipo_id) do update
set importe_inscripcion=excluded.importe_inscripcion,
    admite_fraccionamiento=excluded.admite_fraccionamiento,
    requiere_pago_ficha=excluded.requiere_pago_ficha,
    observaciones='TEST-S v1';

-- 23 tutor Personas, one family per team.
with teams as (select e.*, row_number() over(order by e.codigo) n from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa')
insert into public.personas(id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,telefono,activo)
select private.test_uuid('tutor:'||codigo),'Tutor TEST', 'Familia '||lpad(n::text,2,'0'), null,date '1985-01-01' + n::int,
       'tutor'||lpad(n::text,2,'0')||'@test.invalid','600'||lpad(n::text,6,'0'),true from teams
on conflict(id) do update set email_contacto=excluded.email_contacto,activo=true;
insert into private.test_dataset_entities select 'TEST-S','personas',private.test_uuid('tutor:'||e.codigo),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa' on conflict do nothing;

-- 46 player Personas: exactly two per active team, with age derived from category rules.
with teams as (
 select e.*,c.codigo cat_codigo,coalesce(r.anio_nacimiento_hasta,2000) birth_year,row_number() over(order by e.codigo) team_n
 from public.equipos e join public.temporadas t on t.id=e.temporada_id join public.categorias c on c.id=e.categoria_id
 left join public.reglas_categoria_temporada r on r.temporada_id=e.temporada_id and r.categoria_id=e.categoria_id and r.activo
 where t.estado='activa'
), p as (select teams.*,g from teams cross join generate_series(1,2) g)
insert into public.personas(id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,activo)
select private.test_uuid('player:'||codigo||':'||g), 'Jugador TEST', codigo||' '||lpad(g::text,2,'0'), null,
       make_date(birth_year, case when g=1 then 3 else 9 end, case when g=1 then 10 else 20 end),
       lower(codigo)||'-'||g||'@test.invalid',true from p
on conflict(id) do update set fecha_nacimiento=excluded.fecha_nacimiento,email_contacto=excluded.email_contacto,activo=true;
insert into private.test_dataset_entities select 'TEST-S','personas',private.test_uuid('player:'||e.codigo||':'||g),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2) g where t.estado='activa' on conflict do nothing;

-- Player facets, inscriptions and team assignments.
insert into public.jugadores(id,persona_id,activo,fecha_alta)
select private.test_uuid('jugador:'||e.codigo||':'||g),private.test_uuid('player:'||e.codigo||':'||g),true,date '2026-07-01'
from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2) g where t.estado='activa'
on conflict(id) do update set activo=true;
insert into private.test_dataset_entities select 'TEST-S','jugadores',private.test_uuid('jugador:'||e.codigo||':'||g),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2) g where t.estado='activa' on conflict do nothing;

insert into public.inscripciones(id,jugador_id,temporada_id,categoria_id,fecha_solicitud,estado,observaciones)
select private.test_uuid('insc:'||e.codigo||':'||g),private.test_uuid('jugador:'||e.codigo||':'||g),e.temporada_id,e.categoria_id,date '2026-09-01',
       (array['pendiente_revision_inicial','datos_validados','documentacion_validada','lista_para_federar','ficha_tramitada'])[((row_number() over(order by e.codigo,g)-1)%5)+1], 'TEST-S v1'
from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2) g where t.estado='activa'
on conflict(id) do update set estado=excluded.estado,observaciones='TEST-S v1';
insert into private.test_dataset_entities select 'TEST-S','inscripciones',private.test_uuid('insc:'||e.codigo||':'||g),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2) g where t.estado='activa' on conflict do nothing;

insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde,motivo_cambio)
select private.test_uuid('player-team:'||e.codigo||':'||g),private.test_uuid('insc:'||e.codigo||':'||g),e.id,date '2026-09-01','TEST-S baseline'
from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2) g where t.estado='activa'
on conflict(id) do update set equipo_id=excluded.equipo_id,fecha_hasta=null;
insert into private.test_dataset_entities select 'TEST-S','asignaciones_jugador_equipo',private.test_uuid('player-team:'||e.codigo||':'||g),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2) g where t.estado='activa' on conflict do nothing;

-- Representation for minors only. Senior players are self-represented.
insert into public.representaciones_jugador(id,jugador_id,representante_persona_id,fecha_desde,motivo_alta)
select private.test_uuid('repr:'||e.codigo||':'||g),private.test_uuid('jugador:'||e.codigo||':'||g),private.test_uuid('tutor:'||e.codigo),date '2026-07-01','TEST-S tutor'
from public.equipos e join public.temporadas t on t.id=e.temporada_id join public.categorias c on c.id=e.categoria_id cross join generate_series(1,2) g
where t.estado='activa' and c.codigo<>'SEN'
on conflict(id) do update set fecha_hasta=null;
insert into private.test_dataset_entities select 'TEST-S','representaciones_jugador',private.test_uuid('repr:'||e.codigo||':'||g),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id join public.categorias c on c.id=e.categoria_id cross join generate_series(1,2) g where t.estado='activa' and c.codigo<>'SEN' on conflict do nothing;

-- Roles: tutors; adult Senior players get jugador role. Synthetic users remain auth_user_id NULL.
insert into public.persona_roles(id,persona_id,rol_id,fecha_desde,activo)
select private.test_uuid('role:tutor:'||e.codigo),private.test_uuid('tutor:'||e.codigo),'5b569d29-62f1-40b9-bfb7-7a65f62ee8aa',date '2026-07-01',true
from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa' on conflict(id) do update set activo=true;
insert into private.test_dataset_entities select 'TEST-S','persona_roles',private.test_uuid('role:tutor:'||e.codigo),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa' on conflict do nothing;

insert into public.persona_roles(id,persona_id,rol_id,fecha_desde,activo)
select private.test_uuid('role:player:'||e.codigo||':'||g),private.test_uuid('player:'||e.codigo||':'||g),'12451dc8-8225-4861-8b1b-f154810e84d6',date '2026-07-01',true
from public.equipos e join public.temporadas t on t.id=e.temporada_id join public.categorias c on c.id=e.categoria_id cross join generate_series(1,2) g where t.estado='activa' and c.codigo='SEN'
on conflict(id) do update set activo=true;
insert into private.test_dataset_entities select 'TEST-S','persona_roles',private.test_uuid('role:player:'||e.codigo||':'||g),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id join public.categorias c on c.id=e.categoria_id cross join generate_series(1,2) g where t.estado='activa' and c.codigo='SEN' on conflict do nothing;

-- 10 coach-only Personas + first two SEN-A players as player+coach = 12 coaches.
insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,email_contacto,activo)
select private.test_uuid('coach-person:'||n),'Entrenador TEST',lpad(n::text,2,'0'),date '1980-01-01'+n::int,'entrenador'||lpad(n::text,2,'0')||'@test.invalid',true from generate_series(1,10) n
on conflict(id) do update set activo=true,email_contacto=excluded.email_contacto;
insert into private.test_dataset_entities select 'TEST-S','personas',private.test_uuid('coach-person:'||n),now() from generate_series(1,10) n on conflict do nothing;

with cp as (
 select n, private.test_uuid('coach-person:'||n) persona_id from generate_series(1,10)n
 union all select 11,private.test_uuid('player:SEN-A:1') union all select 12,private.test_uuid('player:SEN-A:2')
)
insert into public.entrenadores(id,persona_id,activo,curso_delegado)
select private.test_uuid('coach:'||n),persona_id,true,(n in (1,2,5,11)) from cp
on conflict(id) do update set activo=true,curso_delegado=excluded.curso_delegado;
insert into private.test_dataset_entities select 'TEST-S','entrenadores',private.test_uuid('coach:'||n),now() from generate_series(1,12)n on conflict do nothing;

with cp as (select n, case when n<=10 then private.test_uuid('coach-person:'||n) when n=11 then private.test_uuid('player:SEN-A:1') else private.test_uuid('player:SEN-A:2') end persona_id from generate_series(1,12)n)
insert into public.persona_roles(id,persona_id,rol_id,fecha_desde,activo)
select private.test_uuid('role:coach:'||n),persona_id,'87bf69a0-d64e-4aca-aa47-277cfcad71e6',date '2026-07-01',true from cp
on conflict(id) do update set activo=true;
insert into private.test_dataset_entities select 'TEST-S','persona_roles',private.test_uuid('role:coach:'||n),now() from generate_series(1,12)n on conflict do nothing;

-- Coach seasons and assignments across first 12 teams; coach 12 remains without assignment.
insert into public.entrenador_temporadas(id,entrenador_id,temporada_id,estado,disponibilidad_confirmada_at)
select private.test_uuid('coach-season:'||n),private.test_uuid('coach:'||n),'f6b07c5c-9f57-44f4-a20d-189ab8608eac',case when n=12 then 'sin_asignacion' else 'activo' end,case when n in(3,12) then null else now() end from generate_series(1,12)n
on conflict(id) do update set estado=excluded.estado,disponibilidad_confirmada_at=excluded.disponibilidad_confirmada_at;
insert into private.test_dataset_entities select 'TEST-S','entrenador_temporadas',private.test_uuid('coach-season:'||n),now() from generate_series(1,12)n on conflict do nothing;

with teams as (select e.id,e.codigo,row_number() over(order by e.codigo)n from public.equipos e join public.temporadas t on t.id=e.temporada_id where t.estado='activa')
insert into public.asignaciones_entrenador_equipo(id,entrenador_id,equipo_id,rol,funcion,fecha_desde)
select private.test_uuid('coach-team:'||n),private.test_uuid('coach:'||n),id,case when n%4=0 then 'Preparador fisico' else 'Entrenador' end,
       (array['first','second','goalkeeper','fitness'])[((n-1)%4)+1],date '2026-09-01' from teams where n<=11
on conflict(id) do update set funcion=excluded.funcion,fecha_hasta=null,cancelada_at=null;
insert into private.test_dataset_entities select 'TEST-S','asignaciones_entrenador_equipo',private.test_uuid('coach-team:'||n),now() from generate_series(1,11)n on conflict do nothing;
-- multiteam case: coach 1 also second on team 12
with t as (select id from public.equipos order by codigo offset 11 limit 1)
insert into public.asignaciones_entrenador_equipo(id,entrenador_id,equipo_id,rol,funcion,fecha_desde) select private.test_uuid('coach-team:1b'),private.test_uuid('coach:1'),id,'Entrenador','second',date '2026-09-01' from t on conflict(id) do update set fecha_hasta=null;
insert into private.test_dataset_entities values('TEST-S','asignaciones_entrenador_equipo',private.test_uuid('coach-team:1b'),now()) on conflict do nothing;

-- Seven-day availability for coaches except 3 (pending) and 12 (not required). Coach 4 deliberately conflicts.
insert into public.entrenador_disponibilidad(id,entrenador_id,temporada_id,dia_semana,tipo,hora_desde,hora_hasta)
select private.test_uuid('avail:'||n||':'||d),private.test_uuid('coach:'||n),'f6b07c5c-9f57-44f4-a20d-189ab8608eac',d,
 case when d in(6,7) then 'todo_dia' when n=4 and d=3 then 'franja' else 'desde' end,
 case when d in(6,7) then null when n=4 and d=3 then time '21:00' else time '17:00' end,
 case when n=4 and d=3 then time '22:00' else null end
from generate_series(1,11)n cross join generate_series(1,7)d where n<>3
on conflict(id) do update set tipo=excluded.tipo,hora_desde=excluded.hora_desde,hora_hasta=excluded.hora_hasta;
insert into private.test_dataset_entities select 'TEST-S','entrenador_disponibilidad',private.test_uuid('avail:'||n||':'||d),now() from generate_series(1,11)n cross join generate_series(1,7)d where n<>3 on conflict do nothing;

-- Formation/license cases.
insert into public.entrenador_formaciones(id,entrenador_id,tipo,estado,fecha_inicio,fecha_obtencion,entidad_emisora,verificacion_estado)
values
(private.test_uuid('form:1'),private.test_uuid('coach:1'),'delegado','vigente','2025-09-01','2025-10-01','RFFM','verificada'),
(private.test_uuid('form:2'),private.test_uuid('coach:2'),'delegado','vigente','2025-09-01','2025-10-01','RFFM','verificada'),
(private.test_uuid('form:5'),private.test_uuid('coach:5'),'uefa_c','en_curso','2026-09-01',null,'RFFM','pendiente'),
(private.test_uuid('form:6'),private.test_uuid('coach:6'),'uefa_c','vigente','2025-09-01','2026-06-01','RFFM','verificada')
on conflict(id) do update set estado=excluded.estado,verificacion_estado=excluded.verificacion_estado;
insert into private.test_dataset_entities select 'TEST-S','entrenador_formaciones',private.test_uuid('form:'||n),now() from unnest(array[1,2,5,6]) n on conflict do nothing;

insert into public.entrenador_licencias_rffm(id,entrenador_id,temporada_id,tipo,numero,fecha_expedicion,fecha_caducidad,estado_excepcional,verificacion_estado)
values
(private.test_uuid('lic:1'),private.test_uuid('coach:1'),'f6b07c5c-9f57-44f4-a20d-189ab8608eac','D','TEST-D-001','2026-07-01','2027-06-30',null,'verificada'),
(private.test_uuid('lic:3'),private.test_uuid('coach:3'),'f6b07c5c-9f57-44f4-a20d-189ab8608eac','ET','TEST-ET-003','2026-07-01','2027-06-30',null,'pendiente'),
(private.test_uuid('lic:7'),private.test_uuid('coach:7'),'f6b07c5c-9f57-44f4-a20d-189ab8608eac','D','TEST-D-007','2025-07-01','2026-06-30',null,'verificada'),
(private.test_uuid('lic:8'),private.test_uuid('coach:8'),'f6b07c5c-9f57-44f4-a20d-189ab8608eac','D','TEST-D-008','2026-07-01','2027-06-30','revocada','verificada')
on conflict(id) do update set fecha_caducidad=excluded.fecha_caducidad,estado_excepcional=excluded.estado_excepcional,verificacion_estado=excluded.verificacion_estado;
insert into private.test_dataset_entities select 'TEST-S','entrenador_licencias_rffm',private.test_uuid('lic:'||n),now() from unnest(array[1,3,7,8]) n on conflict do nothing;

-- Economy states for all inscriptions.
with x as (select e.codigo,g,row_number() over(order by e.codigo,g)n from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa')
insert into public.situacion_economica_inscripcion(id,inscripcion_id,configuracion_id,equipo_id,importe_total,importe_pagado,estado_economico,fraccionamiento_clubber_validado,apto_para_ficha)
select private.test_uuid('econ:'||codigo||':'||g),
       private.test_uuid('insc:'||codigo||':'||g),
       (select ce.id
          from public.configuracion_economica_equipo ce
          join public.equipos eq on eq.id=ce.equipo_id
         where eq.codigo=x.codigo
           and ce.temporada_id=eq.temporada_id),
       (select id from public.equipos where codigo=x.codigo),150,
 case n%4 when 0 then 150 when 1 then 0 when 2 then 75 else 50 end,
 case n%4 when 0 then 'pagado' when 1 then 'pendiente' else 'parcial' end,
 (n%4=3),(n%4=0 or n%4=3) from x
on conflict(id) do update set importe_pagado=excluded.importe_pagado,estado_economico=excluded.estado_economico,fraccionamiento_clubber_validado=excluded.fraccionamiento_clubber_validado,apto_para_ficha=excluded.apto_para_ficha;
insert into private.test_dataset_entities select 'TEST-S','situacion_economica_inscripcion',private.test_uuid('econ:'||e.codigo||':'||g),now() from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa' on conflict do nothing;

-- RRMM matrix on first 10 players, relative to load date to preserve semantic states.
with p as (select e.codigo,g,row_number() over(order by e.codigo,g)n from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa' order by e.codigo,g limit 10)
insert into public.reconocimientos_medicos(id,jugador_id,persona_id,fecha_reconocimiento,fecha_valido_hasta,centro_medico,observaciones)
select private.test_uuid('rrmm:'||codigo||':'||g),private.test_uuid('jugador:'||codigo||':'||g),private.test_uuid('player:'||codigo||':'||g),current_date-400,
 case n when 1 then current_date+200 when 2 then current_date+80 when 3 then current_date+20 when 4 then current_date-10 else current_date+300 end,
 'Centro Medico TEST','TEST-S RRMM' from p where n<=5
on conflict(id) do update set fecha_valido_hasta=excluded.fecha_valido_hasta;
insert into private.test_dataset_entities select 'TEST-S','reconocimientos_medicos',private.test_uuid('rrmm:'||codigo||':'||g),now() from (select e.codigo,g,row_number() over(order by e.codigo,g)n from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa')x where n<=5 on conflict do nothing;

-- Citas: future, past-pending, cancelled, no-show.
with p as (select e.codigo,g,row_number() over(order by e.codigo,g)n from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa' order by e.codigo,g limit 10)
insert into public.citas_reconocimiento_medico(id,jugador_id,persona_id,fecha_hora,lugar,direccion,indicaciones,estado)
select private.test_uuid('cita:'||codigo||':'||g),private.test_uuid('jugador:'||codigo||':'||g),private.test_uuid('player:'||codigo||':'||g),
 case n when 6 then now()+interval '10 days' when 7 then now()-interval '2 days' when 8 then now()+interval '15 days' else now()-interval '5 days' end,
 'Centro Medico TEST','Calle TEST 1','Escenario TEST-S',case n when 8 then 'cancelada' when 9 then 'no_asiste' else 'programada' end from p where n between 6 and 9
on conflict(id) do update set fecha_hora=excluded.fecha_hora,estado=excluded.estado;
insert into private.test_dataset_entities select 'TEST-S','citas_reconocimiento_medico',private.test_uuid('cita:'||codigo||':'||g),now() from (select e.codigo,g,row_number() over(order by e.codigo,g)n from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa')x where n between 6 and 9 on conflict do nothing;

-- Minimal documentation cases: one requirement per first six inscriptions, no physical Storage object required.
with p as (select e.codigo,g,row_number() over(order by e.codigo,g)n from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa' order by e.codigo,g limit 6)
insert into public.requisitos_federativos_inscripcion(id,inscripcion_id,codigo,nombre,obligatorio,requiere_archivo,estado,motivo_rechazo)
select private.test_uuid('req:'||codigo||':'||g),private.test_uuid('insc:'||codigo||':'||g),'TEST_DOC','Documento TEST',true,true,
 (array['pendiente','aportado','validado','rechazado','nueva_version_solicitada','declarado_realizado'])[n],case when n=4 then 'Documento ilegible TEST' end from p
on conflict(id) do update set estado=excluded.estado,motivo_rechazo=excluded.motivo_rechazo;
insert into private.test_dataset_entities select 'TEST-S','requisitos_federativos_inscripcion',private.test_uuid('req:'||codigo||':'||g),now() from (select e.codigo,g,row_number() over(order by e.codigo,g)n from public.equipos e join public.temporadas t on t.id=e.temporada_id cross join generate_series(1,2)g where t.estado='activa')x where n<=6 on conflict do nothing;

update private.test_datasets set scenario='BASELINE',loaded_at=now() where id='TEST-S';
commit;
