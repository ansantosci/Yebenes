-- Authenticated family coverage for DEMO-S. ACCESS identities survive dataset resets.
begin;
-- Every minor already has one active representation created by the baseline before inscription.
-- Materialize eligible dataset minors once, then resolve the 13 authenticated-family targets.
create temporary table tmp_authenticated_family_targets on commit drop as
with family_case(n,team_code,slot) as (values (1,'PRE-A',1),(2,'BEN-A',1),(2,'BEN-A',2),(3,'PRE-B',1),(3,'ALE-A',1),(4,'BEN-B',1),(4,'ALE-B',1),(4,'INF-A',1),(5,'CHU-A',1),(5,'PRE-A',2),(5,'INF-B',1),(6,'CAD-A',1),(6,'CAD-F',1)),
eligible as materialized (
  select e.codigo team_code,j.id jugador_id,r.id representacion_id,
         row_number() over(partition by e.id order by j.id) eligible_slot
  from public.equipos e
  join public.asignaciones_jugador_equipo aje on aje.equipo_id=e.id and aje.fecha_hasta is null
  join public.inscripciones i on i.id=aje.inscripcion_id
  join public.jugadores j on j.id=i.jugador_id and j.activo
  join public.personas p on p.id=j.persona_id
  join private.demo_dataset_entities own on own.dataset_id='DEMO-S' and own.table_name='jugadores' and own.entity_id=j.id
  join public.representaciones_jugador r on r.jugador_id=j.id and r.fecha_hasta is null
  where date '2026-09-01' < (p.fecha_nacimiento+interval '18 years')::date
    and not exists(select 1 from private.demo_access_identities ax where ax.persona_id=p.id)
)
select fc.n,fc.team_code,fc.slot,e.jugador_id,e.representacion_id,a.persona_id tutor_id
from family_case fc
join eligible e on e.team_code=fc.team_code and e.eligible_slot=fc.slot
join private.demo_access_identities a on a.key='tutor_family_'||fc.n;

do $$
declare actual integer;
begin
 select count(*) into actual from tmp_authenticated_family_targets;
 if actual<>13 then raise exception 'Family matrix: expected 13 eligible dataset-minor targets, got %',actual; end if;
end $$;

update public.representaciones_jugador r
set representante_persona_id=x.tutor_id,
    motivo_alta='DEMO-S authenticated family'
from tmp_authenticated_family_targets x
where r.id=x.representacion_id;

do $$
declare actual integer;
begin
 select count(*) into actual
 from tmp_authenticated_family_targets x
 join public.representaciones_jugador r on r.id=x.representacion_id
 where r.jugador_id=x.jugador_id and r.representante_persona_id=x.tutor_id and r.fecha_hasta is null;
 if actual<>13 then raise exception 'Family matrix: expected exactly 13 authenticated target representations, got %',actual; end if;
end $$;

-- Tutor family 6 is also a coach.
insert into public.entrenadores(id,persona_id,activo,curso_delegado)
select private.demo_uuid('auth-family-coach:6'),a.persona_id,true,false from private.demo_access_identities a where a.key='tutor_family_6'
on conflict(id) do update set persona_id=excluded.persona_id,activo=true;
insert into private.demo_dataset_entities(dataset_id,table_name,entity_id)
values('DEMO-S','entrenadores',private.demo_uuid('auth-family-coach:6')) on conflict do nothing;

do $$
declare missing_minor integer; linked integer; own_auth integer; same_team integer; cross_team integer; three_children integer; multimodal integer; coach_tutor integer;
begin
 select count(*) into missing_minor from public.jugadores j join public.personas p on p.id=j.persona_id
 where j.activo and date '2026-09-01' < (p.fecha_nacimiento+interval '18 years')::date
 and not exists(select 1 from public.representaciones_jugador r where r.jugador_id=j.id and r.fecha_hasta is null);
 if missing_minor<>0 then raise exception 'Family matrix: % active minors without active representation',missing_minor; end if;
 select count(*) into linked from private.demo_access_identities a join public.personas p on p.id=a.persona_id where a.key like 'tutor_family_%' and p.auth_user_id is not null;
 if linked<>6 then raise exception 'Family matrix: expected 6 additional authenticated tutors, got %',linked; end if;
 select count(*) into own_auth from public.jugadores j join public.personas p on p.id=j.persona_id
 where date '2026-09-01' < (p.fecha_nacimiento+interval '18 years')::date and p.auth_user_id is not null;
 if own_auth<>0 then raise exception 'Family matrix: minors must not have Auth login, got %',own_auth; end if;
 select count(*) into same_team from public.representaciones_jugador r join private.demo_access_identities a on a.persona_id=r.representante_persona_id and a.key='tutor_family_2' where r.fecha_hasta is null;
 if same_team<2 then raise exception 'Family matrix: same-team siblings missing'; end if;
 select count(distinct aje.equipo_id) into cross_team from public.representaciones_jugador r join private.demo_access_identities a on a.persona_id=r.representante_persona_id and a.key='tutor_family_3'
 join public.inscripciones i on i.jugador_id=r.jugador_id join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id and aje.fecha_hasta is null where r.fecha_hasta is null;
 if cross_team<2 then raise exception 'Family matrix: cross-team siblings missing'; end if;
 select count(*) into three_children from public.representaciones_jugador r join private.demo_access_identities a on a.persona_id=r.representante_persona_id and a.key='tutor_family_4' where r.fecha_hasta is null;
 if three_children<3 then raise exception 'Family matrix: three-child family missing'; end if;
 select count(distinct e.modalidad) into multimodal from public.representaciones_jugador r join private.demo_access_identities a on a.persona_id=r.representante_persona_id and a.key='tutor_family_5'
 join public.inscripciones i on i.jugador_id=r.jugador_id join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id and aje.fecha_hasta is null join public.equipos e on e.id=aje.equipo_id where r.fecha_hasta is null;
 if multimodal<3 then raise exception 'Family matrix: F5/F7/F11 family missing'; end if;
 select count(*) into coach_tutor from public.entrenadores c join private.demo_access_identities a on a.persona_id=c.persona_id where a.key='tutor_family_6' and c.activo;
 if coach_tutor<1 then raise exception 'Family matrix: coach+tutor case missing'; end if;
end $$;
commit;
