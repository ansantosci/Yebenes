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

  -- At least one synthetic person must participate in both economy and equipment.
  select count(distinct ec.persona_id) into v_cross
  from public.economia_cargos ec
  join public.equipacion_necesidades en on en.persona_id=ec.persona_id and en.temporada_id=ec.temporada_id
  where exists(select 1 from private.test_dataset_entities e where e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=ec.id)
    and exists(select 1 from private.test_dataset_entities e where e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades' and e.entity_id=en.id);
  if v_cross<1 then raise exception 'COMPLETO: no cross-module person with economy + equipment'; end if;
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
