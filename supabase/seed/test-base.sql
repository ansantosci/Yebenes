-- ============================================================
-- C.D. Los Yebenes San Bruno
-- TEST-BASE - Datos maestros no personales
-- Entorno destino: Supabase TEST
--
-- NO contiene:
-- - personas
-- - jugadores
-- - entrenadores
-- - usuarios Auth
-- - documentos
-- - datos personales
--
-- Idempotente: puede ejecutarse nuevamente.
-- ============================================================

begin;

-- ============================================================
-- 1. ROLES
-- ============================================================

insert into public.roles
  (id, codigo, nombre, descripcion)
values
  (
    '0f554265-2939-4c51-9e08-718179799cfd',
    'administrador',
    'Administrador',
    'Gestion completa de usuarios, configuracion y operativa'
  ),
  (
    '87b630ea-f537-4592-bf6e-8d8bb9bec407',
    'club',
    'Usuario del club',
    'Personal autorizado para la gestion deportiva'
  ),
  (
    '87bf69a0-d64e-4aca-aa47-277cfcad71e6',
    'entrenador',
    'Entrenador',
    'Tecnico asignado a uno o varios equipos'
  ),
  (
    '12451dc8-8225-4861-8b1b-f154810e84d6',
    'jugador',
    'Jugador',
    'Jugador adulto con capacidad de autorrepresentacion'
  ),
  (
    '5b569d29-62f1-40b9-bfb7-7a65f62ee8aa',
    'tutor',
    'Tutor / Familia',
    'Representante de uno o varios jugadores menores'
  )
on conflict (id) do update set
  codigo = excluded.codigo,
  nombre = excluded.nombre,
  descripcion = excluded.descripcion;


-- ============================================================
-- 2. TEMPORADA
-- ============================================================

insert into public.temporadas
  (
    id,
    nombre,
    anio_inicio,
    anio_fin,
    fecha_inicio,
    fecha_fin,
    estado
  )
values
  (
    'f6b07c5c-9f57-44f4-a20d-189ab8608eac',
    '2026/2027',
    2026,
    2027,
    '2026-07-01',
    '2027-06-30',
    'activa'
  )
on conflict (id) do update set
  nombre = excluded.nombre,
  anio_inicio = excluded.anio_inicio,
  anio_fin = excluded.anio_fin,
  fecha_inicio = excluded.fecha_inicio,
  fecha_fin = excluded.fecha_fin,
  estado = excluded.estado;


-- ============================================================
-- 3. CATEGORIAS
-- ============================================================

insert into public.categorias
  (id, codigo, nombre, orden, modalidad, genero, activo)
values
  ('37941ae6-88b4-412b-a87c-5f4e86acbff7','CHU','Chupetin',10,null,null,true),
  ('5198785d-7796-4b54-9099-96d19c73676a','PRE','Prebenjamin',20,null,null,true),
  ('9496145d-3f23-4dba-8e09-abd82a8e5e69','BEN','Benjamin',30,null,null,true),
  ('889dba5e-0dea-4449-a4e4-19c699337f05','ALE','Alevin',40,null,null,true),
  ('fd05a42c-b430-4de9-b76c-1529c94a9c8a','INF','Infantil',50,null,null,true),
  ('5c67d5e8-a7cf-4272-b1ca-4ce2d2cddcef','CAD','Cadete',60,null,null,true),
  ('b81e54d6-2cf2-49af-80a4-8e412e0ea944','JUV','Juvenil',70,null,null,true),
  ('46675387-012d-47b7-ad79-2a34175a618f','SEN','Senior',80,null,null,true)
on conflict (id) do update set
  codigo = excluded.codigo,
  nombre = excluded.nombre,
  orden = excluded.orden,
  modalidad = excluded.modalidad,
  genero = excluded.genero,
  activo = excluded.activo;


-- ============================================================
-- 4. EQUIPOS
-- ============================================================

insert into public.equipos
  (
    id,
    temporada_id,
    categoria_id,
    nombre,
    codigo,
    genero,
    activo,
    modalidad
  )
values
  ('e21f6c94-fadd-4412-8058-2970bc5a480e','f6b07c5c-9f57-44f4-a20d-189ab8608eac','889dba5e-0dea-4449-a4e4-19c699337f05','Alevin A','ALE-A','masculino',true,'F7'),
  ('d0b8b571-5891-4cfe-9c16-8722144c8f08','f6b07c5c-9f57-44f4-a20d-189ab8608eac','889dba5e-0dea-4449-a4e4-19c699337f05','Alevin B','ALE-B','masculino',true,'F7'),
  ('ecc0f268-c155-46f2-a04c-bb3d5d910b55','f6b07c5c-9f57-44f4-a20d-189ab8608eac','889dba5e-0dea-4449-a4e4-19c699337f05','Alevin F11','ALE-F11','masculino',true,'F11'),

  ('9b6ee4c4-0dec-4a7c-b647-a6f97667f896','f6b07c5c-9f57-44f4-a20d-189ab8608eac','9496145d-3f23-4dba-8e09-abd82a8e5e69','Benjamin A','BEN-A','masculino',true,'F7'),
  ('566f2474-9d3e-44d3-9a23-40079e8e3f04','f6b07c5c-9f57-44f4-a20d-189ab8608eac','9496145d-3f23-4dba-8e09-abd82a8e5e69','Benjamin B','BEN-B','masculino',true,'F7'),
  ('ce5c092d-f058-4ea8-b061-b01019b181f7','f6b07c5c-9f57-44f4-a20d-189ab8608eac','9496145d-3f23-4dba-8e09-abd82a8e5e69','Benjamin C','BEN-C','masculino',true,'F7'),

  ('7492314d-9a6f-4c8c-ad50-c5ac830ec23d','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5c67d5e8-a7cf-4272-b1ca-4ce2d2cddcef','Cadete A','CAD-A','masculino',true,null),
  ('6a93f6ba-eda4-49a1-87c1-e12df4fad3cb','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5c67d5e8-a7cf-4272-b1ca-4ce2d2cddcef','Cadete B','CAD-B','masculino',true,null),
  ('03f79079-4523-4803-8af9-b8c3cb4513aa','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5c67d5e8-a7cf-4272-b1ca-4ce2d2cddcef','Cadete C','CAD-C','masculino',true,null),
  ('b70a6dee-7b26-40f4-a924-92c6df39e472','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5c67d5e8-a7cf-4272-b1ca-4ce2d2cddcef','Cadete Femenino','CAD-F','femenino',true,null),

  ('56546387-63e6-4cf1-87a5-9c2ff1af17e1','f6b07c5c-9f57-44f4-a20d-189ab8608eac','37941ae6-88b4-412b-a87c-5f4e86acbff7','Chupetines','CHU-A','mixto',true,null),

  ('7a48e397-b059-4eab-aab0-1d4395c9093d','f6b07c5c-9f57-44f4-a20d-189ab8608eac','fd05a42c-b430-4de9-b76c-1529c94a9c8a','Infantil A','INF-A','masculino',true,'F11'),
  ('4cf8a784-fead-4208-b4a3-2b7c5db5477c','f6b07c5c-9f57-44f4-a20d-189ab8608eac','fd05a42c-b430-4de9-b76c-1529c94a9c8a','Infantil B','INF-B','masculino',true,null),
  ('95bd3687-2606-4573-b1a2-3fb62f0447fd','f6b07c5c-9f57-44f4-a20d-189ab8608eac','fd05a42c-b430-4de9-b76c-1529c94a9c8a','Infantil Femenino A','INF-FA','femenino',true,null),
  ('56b6183d-a492-493c-b764-51e67846493b','f6b07c5c-9f57-44f4-a20d-189ab8608eac','fd05a42c-b430-4de9-b76c-1529c94a9c8a','Infantil Femenino B','INF-FB','femenino',true,null),

  ('ef3577eb-dd74-455a-9202-2aa813ec0800','f6b07c5c-9f57-44f4-a20d-189ab8608eac','b81e54d6-2cf2-49af-80a4-8e412e0ea944','Juvenil A','JUV-A','masculino',true,null),
  ('7776e2ac-9bb7-4008-8401-40ea8d471d2c','f6b07c5c-9f57-44f4-a20d-189ab8608eac','b81e54d6-2cf2-49af-80a4-8e412e0ea944','Juvenil B','JUV-B','masculino',true,null),
  ('3317e7ac-ae6c-4bf1-8605-cacae92fa8ca','f6b07c5c-9f57-44f4-a20d-189ab8608eac','b81e54d6-2cf2-49af-80a4-8e412e0ea944','Juvenil C','JUV-C','masculino',true,'F11'),

  ('de597922-5e76-415f-8824-9bef995c4fb1','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5198785d-7796-4b54-9099-96d19c73676a','Prebenjamin A','PRE-A','mixto',true,'F7'),
  ('4e419c93-e881-4e83-908e-4597563950ff','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5198785d-7796-4b54-9099-96d19c73676a','Prebenjamin B','PRE-B','mixto',true,'F7'),

  ('f951e14a-dc0e-43fd-8f58-36cb68aa378b','f6b07c5c-9f57-44f4-a20d-189ab8608eac','46675387-012d-47b7-ad79-2a34175a618f','Senior A','SEN-A','masculino',true,'F11'),
  ('93e08be0-cab1-4003-81b2-52d1cb4116f5','f6b07c5c-9f57-44f4-a20d-189ab8608eac','46675387-012d-47b7-ad79-2a34175a618f','Senior B','SEN-B','masculino',true,'F11'),
  ('9c42c5ca-b331-4a68-a175-eec82e723a30','f6b07c5c-9f57-44f4-a20d-189ab8608eac','46675387-012d-47b7-ad79-2a34175a618f','Senior Femenino','SEN-F','femenino',true,'F11')
on conflict (id) do update set
  temporada_id = excluded.temporada_id,
  categoria_id = excluded.categoria_id,
  nombre = excluded.nombre,
  codigo = excluded.codigo,
  genero = excluded.genero,
  activo = excluded.activo,
  modalidad = excluded.modalidad;


-- ============================================================
-- 5. REGLAS CATEGORIA / TEMPORADA
-- ============================================================

insert into public.reglas_categoria_temporada
  (
    id,
    temporada_id,
    categoria_id,
    anio_nacimiento_desde,
    anio_nacimiento_hasta,
    activo
  )
values
  ('68ee39d8-f592-4c5b-8e73-06c19ea749f3','f6b07c5c-9f57-44f4-a20d-189ab8608eac','37941ae6-88b4-412b-a87c-5f4e86acbff7',2021,2022,true),
  ('1514eda0-1cd5-4bc4-b8ef-9d9a3112658e','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5198785d-7796-4b54-9099-96d19c73676a',2019,2020,true),
  ('783d1393-5895-41b4-993a-a36803c34c7f','f6b07c5c-9f57-44f4-a20d-189ab8608eac','9496145d-3f23-4dba-8e09-abd82a8e5e69',2017,2018,true),
  ('266ab849-0dd2-4b6f-9c1f-8910e6d43b9b','f6b07c5c-9f57-44f4-a20d-189ab8608eac','889dba5e-0dea-4449-a4e4-19c699337f05',2015,2016,true),
  ('a24e791b-3f1d-4c30-afcb-2d86d638691e','f6b07c5c-9f57-44f4-a20d-189ab8608eac','fd05a42c-b430-4de9-b76c-1529c94a9c8a',2013,2014,true),
  ('212ae48f-d3d6-46b4-bc07-7487f1bd9660','f6b07c5c-9f57-44f4-a20d-189ab8608eac','5c67d5e8-a7cf-4272-b1ca-4ce2d2cddcef',2011,2012,true),
  ('47fcc000-67f2-4fe3-b13a-15f9935eda09','f6b07c5c-9f57-44f4-a20d-189ab8608eac','b81e54d6-2cf2-49af-80a4-8e412e0ea944',2008,2010,true),
  ('3327bb7f-59fa-4611-b89e-65080e34fafd','f6b07c5c-9f57-44f4-a20d-189ab8608eac','46675387-012d-47b7-ad79-2a34175a618f',null,2007,true)
on conflict (id) do update set
  temporada_id = excluded.temporada_id,
  categoria_id = excluded.categoria_id,
  anio_nacimiento_desde = excluded.anio_nacimiento_desde,
  anio_nacimiento_hasta = excluded.anio_nacimiento_hasta,
  activo = excluded.activo;


-- ============================================================
-- 6. CONFIGURACION VISUAL
-- ============================================================

insert into public.configuracion_visual_club
  (
    id,
    nombre_club,
    logo_url,
    color_primario,
    color_primario_oscuro,
    color_acento,
    color_fondo,
    color_tarjeta,
    color_texto
  )
values
  (
    1,
    'C.D. Los Yebenes San Bruno',
    'https://losyebenessanbruno.es/wp-content/uploads/2023/03/cvncvn.png',
    '#c51230',
    '#8f0c22',
    '#f4c542',
    '#f5f6f8',
    '#ffffff',
    '#20232a'
  )
on conflict (id) do update set
  nombre_club = excluded.nombre_club,
  logo_url = excluded.logo_url,
  color_primario = excluded.color_primario,
  color_primario_oscuro = excluded.color_primario_oscuro,
  color_acento = excluded.color_acento,
  color_fondo = excluded.color_fondo,
  color_tarjeta = excluded.color_tarjeta,
  color_texto = excluded.color_texto;


-- ============================================================
-- 7. SALVAGUARDA
-- TEST-BASE fase 1 no debe crear personas.
-- ============================================================

do $$
begin
  if exists (select 1 from public.personas) then
    raise exception
      'TEST-BASE abortado: public.personas no esta vacia. Revisar el entorno antes de continuar.';
  end if;
end
$$;


commit;


-- ============================================================
-- VALIDACION
-- ============================================================

select '01_roles' as bloque, count(*) as valor
from public.roles

union all

select '02_temporadas', count(*)
from public.temporadas

union all

select '03_categorias', count(*)
from public.categorias

union all

select '04_equipos', count(*)
from public.equipos

union all

select '05_reglas_categoria_temporada', count(*)
from public.reglas_categoria_temporada

union all

select '06_configuracion_visual_club', count(*)
from public.configuracion_visual_club

union all

select '07_personas', count(*)
from public.personas

order by bloque;
