-- Reset only entities registered as TEST-S v1. TEST-BASE and control identities survive.
begin;
-- break the known circular reference before deleting documents/requisites
update public.requisitos_federativos_inscripcion r set current_documento_id=null
where exists (select 1 from private.test_dataset_entities e where e.dataset_id='TEST-S' and e.table_name='requisitos_federativos_inscripcion' and e.entity_id=r.id);
-- children first
DO $$ declare t text; begin
  foreach t in array ARRAY[
    'notificaciones_salida','historico_citas_rrmm','citas_reconocimiento_medico','reconocimientos_medicos',
    'documentos_federativos','requisitos_federativos_inscripcion','pagos_inscripcion','situacion_economica_inscripcion',
    'historico_estados_inscripcion','asignaciones_jugador_equipo','representaciones_jugador',
'entrenador_licencias_rffm','entrenador_formaciones','entrenador_disponibilidad',
    'entrenador_temporadas','asignaciones_entrenador_equipo','entrenador_privacidad','autorizaciones_menor',
    'inscripciones','entrenadores','jugadores','persona_roles','documentos_identidad','horarios_equipo','configuracion_economica_equipo','personas'
  ] loop
    execute format('delete from public.%I x where exists (select 1 from private.test_dataset_entities e where e.dataset_id=$1 and e.table_name=$2 and e.entity_id=x.id)',t) using 'TEST-S',t;
  end loop;
end $$;
delete from private.test_dataset_entities where dataset_id='TEST-S';
delete from private.test_datasets where id='TEST-S';
commit;
