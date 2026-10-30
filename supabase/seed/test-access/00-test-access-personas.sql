-- TEST-ACCESS: permanent synthetic login identities for Supabase TEST.
-- These Personas survive TEST-S RESET. Auth users are created separately by the workflow.
begin;

-- Infrastructure for private.test_access_identities is owned by supabase/test-support.
-- A minor is represented by its tutor. Retire the former standalone login while
-- preserving its historical rows as inactive rather than risking a destructive
-- removal of referenced test data.
update public.personas
set auth_user_id = null,
    email_contacto = null,
    activo = false
where id = '10000000-0000-4000-8000-000000000006';

update public.jugadores
set activo = false,
    fecha_baja = current_date
where persona_id = '10000000-0000-4000-8000-000000000006';

update public.persona_roles
set activo = false,
    fecha_hasta = current_date
where persona_id = '10000000-0000-4000-8000-000000000006';

delete from private.test_access_identities where key = 'minor_player';

insert into private.test_access_identities(key,persona_id,email,description) values
 ('club','10000000-0000-4000-8000-000000000001','club.test@yebenes.test','Club only'),
 ('coach','10000000-0000-4000-8000-000000000002','coach.test@yebenes.test','Coach only'),
 ('coach_player','10000000-0000-4000-8000-000000000003','coach-player.test@yebenes.test','Coach + adult player'),
 ('tutor','10000000-0000-4000-8000-000000000004','tutor.test@yebenes.test','Tutor / family'),
 ('adult_player','10000000-0000-4000-8000-000000000005','player-adult.test@yebenes.test','Adult player'),
 ('multiprofile','10000000-0000-4000-8000-000000000007','multiprofile.test@yebenes.test','Club + coach + player')
on conflict(key) do update set persona_id=excluded.persona_id,email=excluded.email,description=excluded.description;

insert into public.personas(id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,telefono,activo)
select persona_id,
       case key when 'club' then 'Club TEST' when 'coach' then 'Entrenador TEST Acceso' when 'coach_player' then 'Entrenador Jugador TEST'
                when 'tutor' then 'Tutor TEST Acceso' when 'adult_player' then 'Jugador Adulto TEST'
                else 'Multiperfil TEST' end,
       'Acceso', null,
       date '1988-05-15',
       email,
       '610'||lpad((row_number() over(order by key))::text,6,'0'),
       true
from private.test_access_identities
on conflict(id) do update set email_contacto=excluded.email_contacto,telefono=excluded.telefono,activo=true;

-- Every permanent functional TEST identity has a deterministic valid Spanish DNI.
-- This prevents login profiles from being technically valid but unusable in real forms.
with access_docs as (
  -- Do not derive numbers from row order: removing a retired identity would
  -- otherwise try to reassign its already-issued document to another Persona.
  select persona_id,
         case key
           when 'adult_player' then 71000001
           when 'club' then 71000002
           when 'coach' then 71000003
           when 'coach_player' then 71000004
           when 'multiprofile' then 71000006
           when 'tutor' then 71000007
         end as dni_number
  from private.test_access_identities
), docs as (
  select persona_id,
         lpad(dni_number::text,8,'0') || substring('TRWAGMYFPDXBNJZSQVHLCKE' from (dni_number % 23)+1 for 1) as dni
  from access_docs
)
insert into public.documentos_identidad(id,persona_id,tipo,numero,pais_emisor,es_principal,fecha_desde,activo)
select private.test_uuid('access-document:'||persona_id::text),persona_id,'dni',dni,'ES',true,date '2026-07-01',true
from docs
on conflict(id) do update set numero=excluded.numero,es_principal=true,fecha_hasta=null,activo=true;

-- Stable roles for login testing. These rows are TEST-ACCESS, not TEST-S, and survive dataset resets.
with m(key,role_code) as (values
 ('club','club'),('coach','entrenador'),('coach_player','entrenador'),('coach_player','jugador'),('tutor','tutor'),
 ('adult_player','jugador'),('multiprofile','club'),('multiprofile','entrenador'),('multiprofile','jugador')
)
insert into public.persona_roles(id,persona_id,rol_id,fecha_desde,activo)
select private.test_uuid('access-role:'||m.key||':'||m.role_code),a.persona_id,r.id,date '2026-07-01',true
from m join private.test_access_identities a on a.key=m.key join public.roles r on r.codigo=m.role_code
on conflict(id) do update set activo=true,fecha_hasta=null;

-- Permanent facets required for the login profiles. Scenario-specific operational data remains in TEST-S.
insert into public.entrenadores(id,persona_id,activo)
select private.test_uuid('access-coach:'||key),persona_id,true from private.test_access_identities where key in ('coach','coach_player','multiprofile')
on conflict(id) do update set activo=true;

insert into public.jugadores(id,persona_id,activo,fecha_alta)
select private.test_uuid('access-player:'||key),persona_id,true,date '2026-07-01' from private.test_access_identities where key in ('coach_player','adult_player','multiprofile')
on conflict(id) do update set activo=true,fecha_baja=null;

commit;

select a.key,a.email,p.id as persona_id,p.auth_user_id,array_agg(r.codigo order by r.codigo) as roles
from private.test_access_identities a join public.personas p on p.id=a.persona_id
left join public.persona_roles pr on pr.persona_id=p.id and pr.activo
left join public.roles r on r.id=pr.rol_id
group by a.key,a.email,p.id,p.auth_user_id order by a.key;
