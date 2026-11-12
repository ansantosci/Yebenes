-- TEST-S COMPLETO v1
-- Final cross-module validation after BASELINE + ECONOMIA + EQUIPACIONES + NOTIFICATIONS.
begin;

do $$
declare
  v_players integer;
  v_coaches integer;
  v_econ integer;
  v_needs integer;
  v_assign integer;
  v_orders integer;
  v_notifications integer;
  v_cross integer;
begin
  select count(*) into v_players
  from public.jugadores j join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id;
  select count(*) into v_coaches
  from public.entrenadores c join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='entrenadores' and e.entity_id=c.id;
  select count(*) into v_econ
  from public.economia_cargos c
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=c.id);
  select count(*) into v_needs
  from public.equipacion_necesidades n
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades' and e.entity_id=n.id);
  select count(*) into v_assign
  from public.equipacion_asignaciones a
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='equipacion_asignaciones' and e.entity_id=a.id);
  select count(*) into v_orders
  from public.equipacion_pedidos p
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='equipacion_pedidos' and e.entity_id=p.id);
  select count(*) into v_notifications
  from public.notificaciones_salida n
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='notificaciones_salida' and e.entity_id=n.id);

  if v_players<1 then raise exception 'COMPLETO: baseline players missing'; end if;
  if v_coaches<1 then raise exception 'COMPLETO: baseline coaches missing'; end if;
  if v_econ<1 then raise exception 'COMPLETO: economy overlay missing'; end if;
  if v_needs<1 or v_assign<1 then raise exception 'COMPLETO: equipment logistics missing (needs %, assignments %)',v_needs,v_assign; end if;
  if v_orders<1 then raise exception 'COMPLETO: equipment orders missing'; end if;
  if v_notifications<1 then raise exception 'COMPLETO: notifications overlay missing'; end if;

  -- Cross-module coverage is validated after the deterministic bridge below.
  null;
end $$;


-- Deterministic cross-module bridge for end-to-end UI:
-- the first ECONOMIA player also gets one ordinary equipment need in the same season.
with target as (
  select ec.persona_id,ec.temporada_id,j.id jugador_id
  from public.economia_cargos ec
  join public.jugadores j on j.persona_id=ec.persona_id
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=ec.id)
  order by ec.persona_id limit 1
), pack as (
  select p.id from public.equipacion_packs p
  join target t on t.temporada_id=p.temporada_id
  order by p.created_at,p.id limit 1
)
insert into public.equipacion_necesidades(
 id,persona_id,temporada_id,faceta,jugador_id,pack_id,estado,origen,comunicada_at)
select private.test_uuid('complete:cross:need'),t.persona_id,t.temporada_id,'jugador',t.jugador_id,p.id,
       'comunicada','manual',now()
from target t cross join pack p
on conflict(id) do update set persona_id=excluded.persona_id,temporada_id=excluded.temporada_id,
 jugador_id=excluded.jugador_id,pack_id=excluded.pack_id,estado='comunicada',updated_at=now();

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
values('TEST-S','equipacion_necesidades',private.test_uuid('complete:cross:need'))
on conflict do nothing;

do $$
begin
 if not exists(
   select 1 from public.economia_cargos ec
   join public.equipacion_necesidades en
     on en.persona_id=ec.persona_id and en.temporada_id=ec.temporada_id
   where exists(select 1 from private.test_dataset_entities e
                where e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=ec.id)
     and exists(select 1 from private.test_dataset_entities e
                where e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades' and e.entity_id=en.id)
 ) then raise exception 'COMPLETO: deterministic economy + equipment cross-module person missing'; end if;
end $$;

update private.test_datasets
set scenario='COMPLETO',loaded_at=now(),
    metadata=jsonb_build_object(
      'purpose','integrated functional frontend dataset',
      'version','v1',
      'overlays',jsonb_build_array('BASELINE','ECONOMIA','EQUIPACIONES','NOTIFICATIONS')
    )
where id='TEST-S';

commit;
