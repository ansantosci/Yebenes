-- DEMO-ACCESS: permanent synthetic login identities for Supabase DEMO.
-- They intentionally survive DEMO-S RESET. Auth users are provisioned by the
-- separate manual workflow, never by this SQL script.
begin;

-- A minor is represented by its tutor and never receives a standalone login.
-- Keep its deterministic Persona/player as a DEMO family fixture, but remove
-- the Auth association and the access-only role/registry entry.
update public.personas
set auth_user_id = null,
    email_contacto = null,
    activo = true
where id = '20000000-0000-4000-8000-000000000006';

update public.persona_roles
set activo = false,
    fecha_hasta = current_date
where persona_id = '20000000-0000-4000-8000-000000000006';

delete from private.demo_access_identities where key = 'minor_player',
 ('tutor_family_1','20000000-0000-4000-8000-000000000101','tutor-family-1.demo@yebenes.demo.invalid','Synthetic tutor family case 1'),
 ('tutor_family_2','20000000-0000-4000-8000-000000000102','tutor-family-2.demo@yebenes.demo.invalid','Synthetic tutor family case 2'),
 ('tutor_family_3','20000000-0000-4000-8000-000000000103','tutor-family-3.demo@yebenes.demo.invalid','Synthetic tutor family case 3'),
 ('tutor_family_4','20000000-0000-4000-8000-000000000104','tutor-family-4.demo@yebenes.demo.invalid','Synthetic tutor family case 4'),
 ('tutor_family_5','20000000-0000-4000-8000-000000000105','tutor-family-5.demo@yebenes.demo.invalid','Synthetic tutor family case 5'),
 ('tutor_family_6','20000000-0000-4000-8000-000000000106','tutor-family-6.demo@yebenes.demo.invalid','Synthetic tutor family case 6')
on conflict (key) do update
set persona_id = excluded.persona_id,
    email = excluded.email,
    description = excluded.description;

insert into public.personas(id, nombre, primer_apellido, segundo_apellido, fecha_nacimiento, email_contacto, telefono, activo)
select persona_id,
       case key
         when 'club' then 'Club DEMO'
         when 'coach' then 'Entrenador DEMO Acceso'
         when 'coach_player' then 'Entrenador Jugador DEMO'
         when 'tutor' then 'Tutor DEMO Acceso' when 'tutor_family_1' then 'Tutor Familia 1 DEMO' when 'tutor_family_2' then 'Tutor Familia 2 DEMO' when 'tutor_family_3' then 'Tutor Familia 3 DEMO' when 'tutor_family_4' then 'Tutor Familia 4 DEMO' when 'tutor_family_5' then 'Tutor Familia 5 DEMO' when 'tutor_family_6' then 'Tutor Familia 6 DEMO'
         when 'adult_player' then 'Jugador Adulto DEMO'
         else 'Multiperfil DEMO'
       end,
       'Acceso',
       null,
       date '1988-05-15',
       email,
       '612' || lpad((row_number() over (order by key))::text, 6, '0'),
       true
from private.demo_access_identities
on conflict (id) do update
set fecha_nacimiento = excluded.fecha_nacimiento,
    email_contacto = excluded.email_contacto,
    telefono = excluded.telefono,
    activo = true;

-- Deterministic minor fixture for the tutor/family demo. It deliberately does
-- not appear in private.demo_access_identities and has no authentication user.
insert into public.personas(id, nombre, primer_apellido, segundo_apellido, fecha_nacimiento, email_contacto, telefono, activo)
values ('20000000-0000-4000-8000-000000000006', 'Jugador Menor DEMO', 'Tutorizado', null,
        date '2012-05-15', null, '612000006', true)
on conflict (id) do update
set nombre = excluded.nombre,
    primer_apellido = excluded.primer_apellido,
    fecha_nacimiento = excluded.fecha_nacimiento,
    email_contacto = null,
    telefono = excluded.telefono,
    activo = true,
    auth_user_id = null;

-- Functional login profiles need a real, valid identity document for the
-- same forms that are shown in a club demo.
with access_docs as (
  -- Keep identity documents stable when a retired login disappears from the
  -- registry; positional numbering would violate the unique DNI constraint.
  select persona_id,
         case key
           when 'adult_player' then 76000001
           when 'club' then 76000002
           when 'coach' then 76000003
           when 'coach_player' then 76000004
           when 'multiprofile' then 76000006
           when 'tutor' then 76000007
           when 'tutor_family_1' then 76000101
           when 'tutor_family_2' then 76000102
           when 'tutor_family_3' then 76000103
           when 'tutor_family_4' then 76000104
           when 'tutor_family_5' then 76000105
           when 'tutor_family_6' then 76000106
         end as dni_number
  from private.demo_access_identities
), docs as (
  select persona_id,
         lpad(dni_number::text, 8, '0') || substring('TRWAGMYFPDXBNJZSQVHLCKE' from (dni_number % 23) + 1 for 1) as dni
  from access_docs
)
insert into public.documentos_identidad(id, persona_id, tipo, numero, pais_emisor, es_principal, fecha_desde, activo)
select private.demo_uuid('access-document:' || persona_id::text), persona_id, 'dni', dni, 'ES', true, date '2026-07-01', true
from docs
on conflict (id) do update
set numero = excluded.numero,
    es_principal = true,
    fecha_hasta = null,
    activo = true;

insert into public.documentos_identidad(id, persona_id, tipo, numero, pais_emisor, es_principal, fecha_desde, activo)
values (private.demo_uuid('access-document:20000000-0000-4000-8000-000000000006'),
        '20000000-0000-4000-8000-000000000006', 'dni', '76000005R', 'ES', true, date '2026-07-01', true)
on conflict (id) do update
set numero = excluded.numero,
    es_principal = true,
    fecha_hasta = null,
    activo = true;

-- Permanent profile capabilities. They are not owned by DEMO-S.
with mapping(key, role_code) as (values
  ('club', 'club'),
  ('coach', 'entrenador'),
  ('coach_player', 'entrenador'),
  ('coach_player', 'jugador'),
  ('tutor', 'tutor'),
  ('tutor_family_1', 'tutor'),
  ('tutor_family_2', 'tutor'),
  ('tutor_family_3', 'tutor'),
  ('tutor_family_4', 'tutor'),
  ('tutor_family_5', 'tutor'),
  ('tutor_family_6', 'tutor'),
  ('adult_player', 'jugador'),
  ('multiprofile', 'club'),
  ('multiprofile', 'entrenador'),
  ('multiprofile', 'jugador')
)
insert into public.persona_roles(id, persona_id, rol_id, fecha_desde, activo)
select private.demo_uuid('access-role:' || mapping.key || ':' || mapping.role_code), identity.persona_id, role.id, date '2026-07-01', true
from mapping
join private.demo_access_identities identity on identity.key = mapping.key
join public.roles role on role.codigo = mapping.role_code
on conflict (id) do update set activo = true, fecha_hasta = null;

insert into public.entrenadores(id, persona_id, activo)
select private.demo_uuid('access-coach:' || key), persona_id, true
from private.demo_access_identities
where key in ('coach', 'coach_player', 'multiprofile')
on conflict (id) do update set activo = true;

insert into public.jugadores(id, persona_id, activo, fecha_alta)
select private.demo_uuid('access-player:' || key), persona_id, true, date '2026-07-01'
from private.demo_access_identities
where key in ('coach_player', 'adult_player', 'multiprofile')
on conflict (id) do update set activo = true, fecha_baja = null;

insert into public.jugadores(id, persona_id, activo, fecha_alta)
values (private.demo_uuid('access-player:minor_player'), '20000000-0000-4000-8000-000000000006', true, date '2026-07-01')
on conflict (id) do update set activo = true, fecha_baja = null;

commit;

select identity.key, identity.email, persona.id as persona_id, persona.auth_user_id,
       array_agg(role.codigo order by role.codigo) as roles
from private.demo_access_identities identity
join public.personas persona on persona.id = identity.persona_id
left join public.persona_roles persona_role on persona_role.persona_id = persona.id and persona_role.activo
left join public.roles role on role.id = persona_role.rol_id
group by identity.key, identity.email, persona.id, persona.auth_user_id
order by identity.key;
