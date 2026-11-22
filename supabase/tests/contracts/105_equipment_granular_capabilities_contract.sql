-- 105 contract - granular Equipment RBAC.
do $$
declare v_def text;
begin
  if exists (select 1 from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id where r.codigo='entrenador' and rc.capacidad_codigo like 'equipment.%manage') then raise exception '105: entrenador received equipment management'; end if;
  if (select count(*) from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id where r.codigo='club' and rc.capacidad_codigo in ('equipment.manage','equipment.stock.manage','equipment.fulfillment.manage','equipment.procurement.manage')) <> 4 then raise exception '105: club equipment capability set incomplete'; end if;
  if (select count(*) from private.rol_capacidades rc join public.roles r on r.id=rc.rol_id where r.codigo='administrador' and rc.capacidad_codigo in ('equipment.manage','equipment.stock.manage','equipment.fulfillment.manage','equipment.procurement.manage')) <> 4 then raise exception '105: admin equipment capability set incomplete'; end if;
  select pg_get_functiondef('public.equipacion_guardar_pedido_borrador(uuid,uuid,jsonb,uuid,text,text)'::regprocedure) into v_def; if v_def not like '%equipment.procurement.manage%' or v_def like '%has_any_role%' then raise exception '105: order draft not converged'; end if;
  select pg_get_functiondef('public.equipacion_cursar_pedido(uuid)'::regprocedure) into v_def; if v_def not like '%equipment.procurement.manage%' or v_def like '%has_any_role%' then raise exception '105: place order not converged'; end if;
  select pg_get_functiondef('public.equipacion_registrar_recepcion_pedido(uuid,jsonb,date,text,text)'::regprocedure) into v_def; if v_def not like '%equipment.stock.manage%' or v_def like '%has_any_role%' then raise exception '105: reception not converged'; end if;
  select pg_get_functiondef('public.equipacion_registrar_stock_existente(uuid,text,integer,uuid,uuid,uuid,uuid,text,text,text)'::regprocedure) into v_def; if v_def not like '%equipment.stock.manage%' or v_def like '%has_any_role%' then raise exception '105: existing stock not converged'; end if;
end $$;
