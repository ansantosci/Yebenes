-- Contract for Equipaciones reception/stock closure.
do $$
begin
  if to_regclass('public.equipacion_movimientos_stock') is null then raise exception '053 contract failed: stock ledger missing'; end if;
  if to_regprocedure('private.equipacion_recalcular_estado_pedido(uuid)') is null then raise exception '053 contract failed: order status function missing'; end if;
  if not exists(select 1 from pg_trigger where tgrelid='public.equipacion_recepcion_lineas'::regclass and tgname='equipacion_recepcion_lineas_aplicar_stock' and not tgisinternal) then raise exception '053 contract failed: reception stock trigger missing'; end if;
  if not (select relrowsecurity from pg_class where oid='public.equipacion_movimientos_stock'::regclass) then raise exception '053 contract failed: ledger RLS disabled'; end if;
end $$;

-- Dataset-independent transactional smoke with TWO simultaneous orders and partial receptions.
begin;
do $$
declare
  tid uuid := '05300000-0000-4000-8000-000000000001';
  aid uuid := '05300000-0000-4000-8000-000000000002';
  lotid uuid := '05300000-0000-4000-8000-000000000003';
  p1 uuid; p2 uuid; l1 uuid; l2 uuid; r1 uuid; r2 uuid; r3 uuid;
  base_stock integer := 2; final_stock integer; pending integer; st1 text; st2 text;
begin
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(tid,'2095/2096 CONTRACT 053',2095,2096,date '2095-07-01',date '2096-06-30','planificacion');

  insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo)
  values(aid,'Articulo contract 053','CONTRACT-053','camiseta','jugador','general',true,true);

  -- Initial physical stock is represented by a traceable valid lot; legacy stock is only its projection.
  insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,referencia_proveedor,cantidad_fisica,cantidad_reservada)
  values(lotid,aid,'3XS',tid,'BASE-053',base_stock,0);
  insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,observaciones)
  values(lotid,tid,'valido',now(),'Contract 053 initial stock');
  perform private.equipacion_recalcular_stock_legacy(tid,aid,'3XS');

  insert into public.equipacion_pedidos(temporada_id,numero,proveedor_nombre,fecha_pedido,estado)
  values(tid,'SMOKE-053-A','Proveedor smoke',current_date,'pedido') returning id into p1;
  insert into public.equipacion_pedidos(temporada_id,numero,proveedor_nombre,fecha_pedido,estado)
  values(tid,'SMOKE-053-B','Proveedor smoke',current_date,'pedido') returning id into p2;
  insert into public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,cantidad_pedida)
  values(p1,aid,'3XS',20) returning id into l1;
  insert into public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,cantidad_pedida)
  values(p2,aid,'3XS',15) returning id into l2;

  insert into public.equipacion_recepciones(pedido_id,referencia) values(p1,'SMOKE-R1') returning id into r1;
  insert into public.equipacion_recepcion_lineas(recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada) values(r1,l1,8,8);
  select estado into st1 from public.equipacion_pedidos where id=p1;
  if st1<>'parcialmente_recibido' then raise exception '053 smoke failed: P1 should be partial after first receipt'; end if;

  insert into public.equipacion_recepciones(pedido_id,referencia) values(p2,'SMOKE-R2') returning id into r2;
  insert into public.equipacion_recepcion_lineas(recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada) values(r2,l2,5,4);
  select estado into st2 from public.equipacion_pedidos where id=p2;
  if st2<>'parcialmente_recibido' then raise exception '053 smoke failed: P2 should be partial'; end if;

  insert into public.equipacion_recepciones(pedido_id,referencia) values(p1,'SMOKE-R3') returning id into r3;
  insert into public.equipacion_recepcion_lineas(recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada) values(r3,l1,12,12);
  select estado into st1 from public.equipacion_pedidos where id=p1;
  if st1<>'recibido' then raise exception '053 smoke failed: P1 should be received'; end if;

  select cantidad_fisica into final_stock from public.equipacion_stock where temporada_id=tid and articulo_id=aid and talla='3XS';
  if final_stock<>base_stock+24 then raise exception '053 smoke failed: accepted stock expected %, got %',base_stock+24,final_stock; end if;

  if (select coalesce(sum(cantidad_fisica),0) from public.equipacion_stock_lotes l
      join public.equipacion_stock_lote_vigencia v on v.lote_id=l.id
      where v.temporada_id=tid and v.estado='valido' and l.articulo_id=aid and l.talla='3XS')<>base_stock+24 then
    raise exception '053 smoke failed: lot authority does not match expected physical stock';
  end if;

  -- P1 contributes zero pending after completion; P2 contributes 11.
  select sum(greatest(pl.cantidad_pedida-coalesce(x.aceptada,0),0))::integer into pending
  from public.equipacion_pedidos pe join public.equipacion_pedido_lineas pl on pl.pedido_id=pe.id
  left join lateral (select sum(rl.cantidad_aceptada)::integer aceptada from public.equipacion_recepcion_lineas rl where rl.pedido_linea_id=pl.id) x on true
  where pe.id in(p1,p2) and pe.estado in('pedido','parcialmente_recibido');
  if pending<>11 then raise exception '053 smoke failed: simultaneous pending supplier expected 11, got %',pending; end if;

  -- Over-acceptance on P2 must be rejected.
  begin
    insert into public.equipacion_recepciones(pedido_id,referencia) values(p2,'SMOKE-OVER') returning id into r2;
    insert into public.equipacion_recepcion_lineas(recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada) values(r2,l2,12,12);
    raise exception '053 smoke failed: over-acceptance was allowed';
  exception when others then
    if sqlerrm='053 smoke failed: over-acceptance was allowed' then raise; end if;
  end;

  if (select count(*) from public.equipacion_movimientos_stock where recepcion_linea_id in(select id from public.equipacion_recepcion_lineas where pedido_linea_id in(l1,l2)))<>3 then
    raise exception '053 smoke failed: expected three reception stock movements';
  end if;
end $$;
rollback;
select '053_equipaciones_recepciones_stock_contract' contract,'PASS' result;
