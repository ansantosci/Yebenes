-- Reset only entities registered as TEST-S v1. TEST-BASE and control identities survive.
begin;
-- break the known circular reference before deleting documents/requisites
update public.requisitos_federativos_inscripcion r set current_documento_id=null
where exists (select 1 from private.test_dataset_entities e where e.dataset_id='TEST-S' and e.table_name='requisitos_federativos_inscripcion' and e.entity_id=r.id);
-- entrenador_privacidad is keyed by entrenador_id, not id.
delete from public.entrenador_privacidad x
where exists (
  select 1
  from private.test_dataset_entities e
  where e.dataset_id='TEST-S'
    and e.table_name='entrenador_privacidad'
    and e.entity_id=x.entrenador_id
);

-- Repair-safe cleanup: older/interrupted TEST-S runs may leave identity documents
-- whose registry row no longer exists. Remove any document owned by a TEST-S person
-- before the generic registry-driven deletion so BASELINE can recreate principal IDs.
delete from public.documentos_identidad d
where exists (
  select 1
  from private.test_dataset_entities e
  where e.dataset_id='TEST-S'
    and e.table_name='personas'
    and e.entity_id=d.persona_id
);

-- TEST-S reset is an administrative teardown, not a business deletion.
-- Reception lines are immutable in normal operation; suspend only the DELETE guard
-- inside this transaction so registered synthetic rows can be removed. If anything
-- fails later, the transaction rollback restores the trigger state automatically.
select private.test_set_reception_delete_guard(false);

-- 062+ logistics creates children automatically (lot, validity and lot reservations).
-- They may survive an interrupted run without registry rows. Remove every such child
-- transitively from registered TEST-S reception lines / assignments before generic teardown.
delete from public.equipacion_ajustes_stock a
where exists (
  select 1 from public.equipacion_stock_lotes l
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_recepcion_lineas'
   and e.entity_id=l.recepcion_linea_id
  where l.id=a.lote_id
)
or exists (
  select 1 from public.equipacion_asignacion_lotes al
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_asignaciones'
   and e.entity_id=al.asignacion_id
  where al.lote_id=a.lote_id
);

delete from public.equipacion_asignacion_lotes al
where exists (
  select 1 from private.test_dataset_entities e
  where e.dataset_id='TEST-S' and e.table_name='equipacion_asignaciones'
    and e.entity_id=al.asignacion_id
)
or exists (
  select 1 from public.equipacion_stock_lotes l
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_recepcion_lineas'
   and e.entity_id=l.recepcion_linea_id
  where l.id=al.lote_id
);

delete from public.equipacion_stock_lote_vigencia v
where exists (
  select 1 from public.equipacion_stock_lotes l
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_recepcion_lineas'
   and e.entity_id=l.recepcion_linea_id
  where l.id=v.lote_id
);

delete from public.equipacion_stock_lotes l
where exists (
  select 1 from private.test_dataset_entities e
  where e.dataset_id='TEST-S' and e.table_name='equipacion_recepcion_lineas'
    and e.entity_id=l.recepcion_linea_id
);

-- Repair-safe logistics closure: derive children from registered TEST-S needs, not only
-- from registry rows for each child. Interrupted/older fixtures may have created assignments
-- and deliveries without registering those generated rows.
delete from public.equipacion_ajustes_stock a
where exists (
  select 1
  from public.equipacion_stock_lotes l
  join public.equipacion_asignacion_lotes al on al.lote_id=l.id
  join public.equipacion_asignaciones x on x.id=al.asignacion_id
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades'
   and e.entity_id=x.necesidad_id
  where l.id=a.lote_id
);

delete from public.equipacion_asignacion_lotes al
where exists (
  select 1
  from public.equipacion_asignaciones x
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades'
   and e.entity_id=x.necesidad_id
  where x.id=al.asignacion_id
);

delete from public.equipacion_entregas d
where exists (
  select 1
  from public.equipacion_asignaciones x
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades'
   and e.entity_id=x.necesidad_id
  where x.id=d.asignacion_id
);

delete from public.equipacion_movimientos_stock m
where m.asignacion_id is not null and exists (
  select 1
  from public.equipacion_asignaciones x
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades'
   and e.entity_id=x.necesidad_id
  where x.id=m.asignacion_id
);

delete from public.equipacion_asignaciones x
where exists (
  select 1 from private.test_dataset_entities e
  where e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades'
    and e.entity_id=x.necesidad_id
);

-- Third logistics root: lots may be created directly for TEST-S articles (manual,
-- historical/reusable or scenario stock) without a reception-line registry relation.
-- Close every FK below those lots before the generic article teardown.
delete from public.equipacion_ajustes_stock a
where exists (
  select 1
  from public.equipacion_stock_lotes l
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_articulos'
   and e.entity_id=l.articulo_id
  where l.id=a.lote_id
);

delete from public.equipacion_asignacion_lotes al
where exists (
  select 1
  from public.equipacion_stock_lotes l
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_articulos'
   and e.entity_id=l.articulo_id
  where l.id=al.lote_id
);

delete from public.equipacion_stock_lote_vigencia v
where exists (
  select 1
  from public.equipacion_stock_lotes l
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='equipacion_articulos'
   and e.entity_id=l.articulo_id
  where l.id=v.lote_id
);

delete from public.equipacion_stock_lotes l
where exists (
  select 1
  from private.test_dataset_entities e
  where e.dataset_id='TEST-S' and e.table_name='equipacion_articulos'
    and e.entity_id=l.articulo_id
);

-- Trigger-generated stock movements are children of TEST-S logistics rows but may not
-- have their own registry entry. Delete them transitively before the generic teardown.
delete from public.equipacion_movimientos_stock m
where (m.recepcion_linea_id is not null and exists (
  select 1 from private.test_dataset_entities e
  where e.dataset_id='TEST-S' and e.table_name='equipacion_recepcion_lineas'
    and e.entity_id=m.recepcion_linea_id
))
or (m.asignacion_id is not null and exists (
  select 1 from private.test_dataset_entities e
  where e.dataset_id='TEST-S' and e.table_name='equipacion_asignaciones'
    and e.entity_id=m.asignacion_id
));

-- Stock rows can predate registry hardening and still reference TEST-S articles.
-- Remove them transitively before deleting registered articles, even when the stock row
-- itself has no test_dataset_entities entry.
delete from public.equipacion_stock s
where exists (
  select 1
  from private.test_dataset_entities e
  where e.dataset_id='TEST-S'
    and e.table_name='equipacion_articulos'
    and e.entity_id=s.articulo_id
);

-- 060 backfill can create participation rows for pre-existing TEST-S people before
-- those participation IDs have ever been registered in test_dataset_entities.
-- Remove participation history and participation rows transitively by TEST-S person
-- before the generic registry-driven teardown.
delete from public.historico_participaciones_temporada h
where exists (
  select 1
  from public.persona_participaciones_temporada p
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S'
   and e.table_name='personas'
   and e.entity_id=p.persona_id
  where p.id=h.participacion_id
);

delete from public.persona_participaciones_temporada p
where exists (
  select 1
  from private.test_dataset_entities e
  where e.dataset_id='TEST-S'
    and e.table_name='personas'
    and e.entity_id=p.persona_id
);

-- 066: 1:1 economic extension uses cargo_id as its primary key, not id.
delete from public.economia_cargo_equipacion x
where exists (
  select 1 from private.test_dataset_entities e
  where e.dataset_id='TEST-S'
    and e.table_name='economia_cargo_equipacion'
    and e.entity_id=x.cargo_id
)
or exists (
  select 1
  from public.economia_cargos c
  join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=c.id
  where c.id=x.cargo_id
);

-- 067: configuration/state tables use natural/composite primary keys, not id.
-- Delete them by TEST-S ownership scope before the generic id-based teardown.
delete from public.economia_cuota_estado x
where exists (select 1 from private.test_dataset_entities e
              where e.dataset_id='TEST-S' and e.table_name='personas' and e.entity_id=x.persona_id)
   or exists (select 1 from private.test_dataset_entities e
              where e.dataset_id='TEST-S' and e.table_name='temporadas' and e.entity_id=x.temporada_id);

delete from public.economia_cuota_equipo_config x
where exists (select 1 from private.test_dataset_entities e
              where e.dataset_id='TEST-S' and e.table_name='equipos' and e.entity_id=x.equipo_id)
   or exists (select 1 from private.test_dataset_entities e
              where e.dataset_id='TEST-S' and e.table_name='temporadas' and e.entity_id=x.temporada_id);

delete from public.economia_cuota_categoria_config x
where exists (select 1 from private.test_dataset_entities e
              where e.dataset_id='TEST-S' and e.table_name='temporadas' and e.entity_id=x.temporada_id);

delete from public.economia_descuento_hermanos_reglas x
where exists (select 1 from private.test_dataset_entities e
              where e.dataset_id='TEST-S' and e.table_name='temporadas' and e.entity_id=x.temporada_id);

delete from public.economia_cuota_temporada_config x
where exists (select 1 from private.test_dataset_entities e
              where e.dataset_id='TEST-S' and e.table_name='temporadas' and e.entity_id=x.temporada_id);

-- remaining registered entities use id as their primary key
DO $$ declare t text; begin
  foreach t in array ARRAY[
    -- 056-058 dependencies must be removed before their parents.
    -- 067 economic dependencies must be removed before persons, players, teams, charges and seasons.
    'economia_regularizaciones_pendientes','economia_hermanos_vinculos_manuales',
    
    'economia_devoluciones','economia_pagos','economia_ajustes','economia_cargos',
    'economia_modalidades_equipacion','economia_conceptos',
    'equipacion_ajustes_stock','equipacion_asignacion_lotes',
    'equipacion_stock_lote_vigencia','equipacion_stock_lotes',
    'equipacion_movimientos_stock',
    'equipacion_entregas','equipacion_asignaciones','equipacion_recepcion_lineas','equipacion_recepciones',
    'equipacion_pedido_lineas','equipacion_pedidos','equipacion_dorsales','equipacion_necesidades',
    'equipacion_tallas_excepcion','equipacion_tallas_persona','equipacion_personas_temporada',
    'equipacion_stock','equipacion_pack_articulos',
    'equipacion_packs','equipacion_proveedores','equipacion_config_temporada','equipacion_articulos',
    'notificaciones_salida','historico_citas_rrmm','citas_reconocimiento_medico','reconocimientos_medicos',
    'documentos_federativos','requisitos_federativos_inscripcion','pagos_inscripcion','situacion_economica_inscripcion',
    'historico_estados_temporada','historico_participaciones_temporada','persona_participaciones_temporada','historico_estados_inscripcion','asignaciones_jugador_equipo','inscripciones','representaciones_jugador',
'entrenador_licencias_rffm','entrenador_formaciones','entrenador_disponibilidad',
    'entrenador_temporadas','asignaciones_entrenador_equipo','autorizaciones_menor',
    'entrenadores','jugadores','persona_roles','documentos_identidad','horarios_equipo','configuracion_economica_equipo','personas','temporadas'
  ] loop
    execute format('delete from public.%I x where exists (select 1 from private.test_dataset_entities e where e.dataset_id=$1 and e.table_name=$2 and e.entity_id=x.id)',t) using 'TEST-S',t;
  end loop;
end $$;
select private.test_set_reception_delete_guard(true);

delete from private.test_dataset_entities where dataset_id='TEST-S';
delete from private.test_datasets where id='TEST-S';
commit;
