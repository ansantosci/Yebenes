-- Removes only rows registered as DEMO-S. Existing users, identities and operational data are untouched.
begin;

update public.requisitos_federativos_inscripcion r
set current_documento_id = null
where exists (
  select 1
  from private.demo_dataset_entities e
  where e.dataset_id = 'DEMO-S'
    and e.table_name = 'requisitos_federativos_inscripcion'
    and e.entity_id = r.id
);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'citas_reconocimiento_medico',
    'reconocimientos_medicos',
    'requisitos_federativos_inscripcion',
    'asignaciones_jugador_equipo',
    'inscripciones',
    'representaciones_jugador',
    'entrenador_disponibilidad',
    'asignaciones_entrenador_equipo',
    'entrenador_temporadas',
    'jugadores',
    'persona_roles',
    'documentos_identidad',
    'personas'
  ] loop
    execute format(
      'delete from public.%I x where exists (
         select 1 from private.demo_dataset_entities e
         where e.dataset_id = $1 and e.table_name = $2 and e.entity_id = x.id
       )',
      table_name
    ) using 'DEMO-S', table_name;
  end loop;
end
$$;

delete from private.demo_dataset_entities where dataset_id = 'DEMO-S';
delete from private.demo_datasets where id = 'DEMO-S';

commit;
