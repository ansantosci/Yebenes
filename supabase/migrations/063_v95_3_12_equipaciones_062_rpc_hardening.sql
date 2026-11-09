-- 063 - Security hardening for operational RPCs introduced/changed by 062.
-- 062 is already immutable in the TEST migration registry; this migration only fixes grants.
begin;

-- Operational APIs: never executable by PUBLIC/anon.
revoke all on function private.equipacion_reservar_asignacion_lote(uuid,uuid,integer) from public,anon;
revoke all on function private.equipacion_ajustar_stock_lote(uuid,integer,text,text) from public,anon;
revoke all on function private.equipacion_confirmar_entrega(uuid,uuid) from public,anon;

grant execute on function private.equipacion_reservar_asignacion_lote(uuid,uuid,integer) to authenticated,service_role;
grant execute on function private.equipacion_ajustar_stock_lote(uuid,integer,text,text) to authenticated,service_role;
grant execute on function private.equipacion_confirmar_entrega(uuid,uuid) to authenticated,service_role;

-- Trigger/internal helpers must not be application APIs.
revoke all on function private.equipacion_validar_pack_necesidad() from public,anon,authenticated;
revoke all on function private.equipacion_recalcular_stock_legacy(uuid,uuid,text) from public,anon,authenticated;
revoke all on function private.equipacion_crear_lote_recepcion() from public,anon,authenticated;

grant execute on function private.equipacion_validar_pack_necesidad() to service_role;
grant execute on function private.equipacion_recalcular_stock_legacy(uuid,uuid,text) to service_role;
grant execute on function private.equipacion_crear_lote_recepcion() to service_role;

commit;
