-- Contract 063: operational Equipaciones RPC grants after 062.
do $$
begin
  if has_function_privilege('anon','private.equipacion_reservar_asignacion_lote(uuid,uuid,integer)','EXECUTE')
     or has_function_privilege('anon','private.equipacion_ajustar_stock_lote(uuid,integer,text,text)','EXECUTE')
     or has_function_privilege('anon','private.equipacion_confirmar_entrega(uuid,uuid)','EXECUTE') then
    raise exception '063 contract failed: operational logistics RPC exposed to anon';
  end if;

  if not has_function_privilege('authenticated','private.equipacion_reservar_asignacion_lote(uuid,uuid,integer)','EXECUTE')
     or not has_function_privilege('authenticated','private.equipacion_ajustar_stock_lote(uuid,integer,text,text)','EXECUTE')
     or not has_function_privilege('authenticated','private.equipacion_confirmar_entrega(uuid,uuid)','EXECUTE') then
    raise exception '063 contract failed: authenticated operational grants missing';
  end if;

  if has_function_privilege('authenticated','private.equipacion_validar_pack_necesidad()','EXECUTE')
     or has_function_privilege('authenticated','private.equipacion_recalcular_stock_legacy(uuid,uuid,text)','EXECUTE')
     or has_function_privilege('authenticated','private.equipacion_crear_lote_recepcion()','EXECUTE') then
    raise exception '063 contract failed: internal helper exposed to authenticated';
  end if;
end $$;

select '063_equipaciones_062_rpc_hardening_contract' as contract,'PASS' as result;
