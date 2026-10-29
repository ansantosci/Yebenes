-- DEMO-ACCESS: permanent synthetic login identities for Supabase DEMO.
-- They intentionally survive DEMO-S RESET. Auth users are provisioned by the
-- separate manual workflow, never by this SQL script.
begin;

insert into private.demo_access_identities(key, persona_id, email, description) values
  ('club',          '20000000-0000-4000-8000-000000000001', 'club.demo@yebenes.demo.invalid',          'Club only'),
  ('coach',         '20000000-0000-4000-8000-000000000002', 'coach.demo@yebenes.demo.invalid',         'Coach only'),
  ('coach_player',  '20000000-0000-4000-8000-000000000003', 'coach-player.demo@yebenes.demo.invalid',  'Coach + adult player'),
  ('tutor',         '20000000-0000-4000-8000-000000000004', 'tutor.demo@yebenes.demo.invalid',         'Tutor / family'),
  ('adult_player',  '20000000-0000-4000-8000-000000000005', 'player-adult.demo@yebenes.demo.invalid',  'Adult player'),
  ('minor_player',  '20000000-0000-4000-8000-000000000006', 'player-minor.demo@yebenes.demo.invalid',  'Minor player access'),
  ('multiprofile',  '20000000-0000-4000-8000-000000000007', 'multiprofile.demo@yebenes.demo.invalid',  'Club + coach + player')
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
         when 'tutor' then 'Tutor DEMO Acceso'
         when 'adult_player' then 'Jugador Adulto DEMO'
         when 'minor_player' then 'Jugador Menor DEMO'
         else 'Multiperfil DEMO'
       end,
       'Acceso',
       null,
       case when key = 'minor_player' then date '2012-05-15' else date '1988-05-15' end,
       email,
       '612' || lpad((row_number() over (order by key))::text, 6, '0'),
       true
from private.demo_access_identities
on conflict (id) do update
set email_contacto = excluded.email_contacto,
    telefono = excluded.telefono,
    activo = true;

-- Functional login profiles need a real, valid identity document for the
-- same forms that are shown in a club demo.
with access_docs as (
  select persona_id, 76000000 + row_number() over (order by key)::int as dni_number
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

-- Permanent profile capabilities. They are not owned by DEMO-S.
with mapping(key, role_code) as (values
  ('club', 'club'),
  ('coach', 'entrenador'),
  ('coach_player', 'entrenador'),
  ('coach_player', 'jugador'),
  ('tutor', 'tutor'),
  ('adult_player', 'jugador'),
  ('minor_player', 'jugador'),
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
where key in ('coach_player', 'adult_player', 'minor_player', 'multiprofile')
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
