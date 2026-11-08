-- V95.3.4 backend - controlled TEST-S cleanup for immutable Equipaciones logistics.
-- Keeps schema/security DDL out of seed files while preserving production immutability rules.

begin;

create or replace function private.test_s_cleanup_equipaciones_logistica()
returns void
language plpgsql
security definer
set search_path=public,private
as $$
begin
  -- Only entities explicitly registered as TEST-S may be removed.
  delete from public.equipacion_movimientos_stock m
  where exists (
    select 1 from private.test_dataset_entities e
    where e.dataset_id='TEST-S'
      and (
        (e.table_name='equipacion_recepcion_lineas' and e.entity_id=m.recepcion_linea_id)
        or (e.table_name='equipacion_asignaciones' and e.entity_id=m.asignacion_id)
        or (e.table_name='equipacion_movimientos_stock' and e.entity_id=m.id)
      )
  );

  -- Reception lines are immutable through the public table trigger.
  -- The controlled helper temporarily disables only the DELETE trigger,
  -- performs a registry-scoped cleanup, then restores it in the same transaction.
  alter table public.equipacion_recepcion_lineas
    disable trigger equipacion_recepcion_lineas_no_delete;

  delete from public.equipacion_recepcion_lineas x
  where exists (
    select 1 from private.test_dataset_entities e
    where e.dataset_id='TEST-S'
      and e.table_name='equipacion_recepcion_lineas'
      and e.entity_id=x.id
  );

  alter table public.equipacion_recepcion_lineas
    enable trigger equipacion_recepcion_lineas_no_delete;
exception
  when others then
    alter table public.equipacion_recepcion_lineas
      enable trigger equipacion_recepcion_lineas_no_delete;
    raise;
end
$$;

revoke all on function private.test_s_cleanup_equipaciones_logistica() from public;
grant execute on function private.test_s_cleanup_equipaciones_logistica() to service_role;

commit;
