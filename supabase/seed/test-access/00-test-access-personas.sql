-- TEST-ACCESS: permanent synthetic login identities for Supabase TEST.
-- These Personas survive TEST-S RESET. Auth users are created separately by the workflow.
begin;

-- Infrastructure for private.test_access_identities is owned by supabase/test-support.
insert into private.test_access_identities(key,persona_id,email,description) values
 ('club','10000000-0000-4000-8000-000000000001','club.test@yebenes.test','Club only'),
 ('coach','10000000-0000-4000-8000-000000000002','coach.test@yebenes.test','Coach only'),
 ('coach_player','10000000-0000-4000-8000-000000000003','coach-player.test@yebenes.test','Coach + adult player'),
 ('tutor','10000000-0000-4000-8000-000000000004','tutor.test@yebenes.test','Tutor / family'),
 ('adult_player','10000000-0000-4000-8000-000000000005','player-adult.test@yebenes.test','Adult player'),
 ('minor_player','10000000-0000-4000-8000-000000000006','player-minor.test@yebenes.test','Minor player access'),
 ('multiprofile','10000000-0000-4000-8000-000000000007','multiprofile.test@yebenes.test','Club + coach + player')
on conflict(key) do update set persona_id=excluded.persona_id,email=excluded.email,description=excluded.description;

insert into public.personas(id,nombre,primer_apellido,segundo_apellido,fecha_nacimiento,email_contacto,activo)
select persona_id,
       case key when 'club' then 'Club TEST' when 'coach' then 'Entrenador TEST Acceso' when 'coach_player' then 'Entrenador Jugador TEST'
                when 'tutor' then 'Tutor TEST Acceso' when 'adult_player' then 'Jugador Adulto TEST' when 'minor_player' then 'Jugador Menor TEST'
                else 'Multiperfil TEST' end,
       'Acceso', null,
       case when key='minor_player' then date '2012-05-15' else date '1988-05-15' end,
       email, true
from private.test_access_identities
on conflict(id) do update set email_contacto=excluded.email_contacto,activo=true;

-- Stable roles for login testing. These rows are TEST-ACCESS, not TEST-S, and survive dataset resets.
with m(key,role_code) as (values
 ('club','club'),('coach','entrenador'),('coach_player','entrenador'),('coach_player','jugador'),('tutor','tutor'),
 ('adult_player','jugador'),('minor_player','jugador'),('multiprofile','club'),('multiprofile','entrenador'),('multiprofile','jugador')
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
select private.test_uuid('access-player:'||key),persona_id,true,date '2026-07-01' from private.test_access_identities where key in ('coach_player','adult_player','minor_player','multiprofile')
on conflict(id) do update set activo=true,fecha_baja=null;

commit;

select a.key,a.email,p.id as persona_id,p.auth_user_id,array_agg(r.codigo order by r.codigo) as roles
from private.test_access_identities a join public.personas p on p.id=a.persona_id
left join public.persona_roles pr on pr.persona_id=p.id and pr.activo
left join public.roles r on r.id=pr.rol_id
group by a.key,a.email,p.id,p.auth_user_id order by a.key;
