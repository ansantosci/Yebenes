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

-- remaining registered entities use id as their primary key
DO $$ declare t text; begin
  foreach t in array ARRAY[
    -- 056-058 dependencies must be removed before their parents.
    'equipacion_stock_lote_vigencia','equipacion_stock_lotes',
    'equipacion_movimientos_stock',
    'equipacion_entregas','equipacion_asignaciones','equipacion_recepcion_lineas','equipacion_recepciones',
    'equipacion_pedido_lineas','equipacion_pedidos','equipacion_dorsales','equipacion_necesidades',
    'equipacion_tallas_excepcion','equipacion_tallas_persona','equipacion_personas_temporada',
    'equipacion_stock','equipacion_pack_articulos',
    'equipacion_packs','equipacion_config_temporada','equipacion_articulos',
    'notificaciones_salida','historico_citas_rrmm','citas_reconocimiento_medico','reconocimientos_medicos',
    'documentos_federativos','requisitos_federativos_inscripcion','pagos_inscripcion','situacion_economica_inscripcion',
    'historico_participaciones_temporada','persona_participaciones_temporada','historico_estados_inscripcion','asignaciones_jugador_equipo','inscripciones','representaciones_jugador',
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
