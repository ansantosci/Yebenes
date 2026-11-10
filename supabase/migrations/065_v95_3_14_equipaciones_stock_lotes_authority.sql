-- 065 - Make traceable lots the single physical-stock authority for receptions.
begin;

create or replace function private.equipacion_aplicar_recepcion_linea()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_pedido_recepcion uuid; v_pedido_linea uuid; v_pedida integer; v_aceptada_previa integer;
begin
  select pedido_id into v_pedido_recepcion
  from public.equipacion_recepciones where id=new.recepcion_id;

  select pl.pedido_id,pl.cantidad_pedida
    into v_pedido_linea,v_pedida
  from public.equipacion_pedido_lineas pl
  where pl.id=new.pedido_linea_id;

  if v_pedido_recepcion is null or v_pedido_linea is null or v_pedido_recepcion<>v_pedido_linea then
    raise exception 'Reception line must belong to the same order as its reception';
  end if;
  if not exists(
    select 1 from public.equipacion_pedidos
    where id=v_pedido_linea and estado in ('pedido','parcialmente_recibido')
  ) then
    raise exception 'Reception can only be registered for an ordered or partially received order';
  end if;

  select coalesce(sum(cantidad_aceptada),0) into v_aceptada_previa
  from public.equipacion_recepcion_lineas
  where pedido_linea_id=new.pedido_linea_id and id<>new.id;

  if v_aceptada_previa+new.cantidad_aceptada>v_pedida then
    raise exception 'Accepted quantity would exceed ordered quantity';
  end if;

  -- Physical stock is NOT changed here. 062/064 creates the traceable lot and
  -- reconciles public.equipacion_stock as a compatibility projection.
  if new.cantidad_aceptada>0 then
    insert into public.equipacion_movimientos_stock(
      temporada_id,articulo_id,talla,tipo,cantidad,recepcion_linea_id,referencia,observaciones)
    select pe.temporada_id,pl.articulo_id,pl.talla,'recepcion',new.cantidad_aceptada,new.id,
           'Recepcion '||new.recepcion_id::text,new.observaciones
    from public.equipacion_pedido_lineas pl
    join public.equipacion_pedidos pe on pe.id=pl.pedido_id
    where pl.id=new.pedido_linea_id;
  end if;

  perform private.equipacion_recalcular_estado_pedido(v_pedido_linea);
  return new;
end $$;

-- Internal trigger helper only.
revoke all on function private.equipacion_aplicar_recepcion_linea() from public,anon,authenticated;
grant execute on function private.equipacion_aplicar_recepcion_linea() to service_role;

commit;
