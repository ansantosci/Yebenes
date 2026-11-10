-- Contract 065: accepted reception is counted once when lots are authoritative.
begin;
do $$
declare
  tid uuid:='06500000-0000-4000-8000-000000000001';
  aid uuid:='06500000-0000-4000-8000-000000000002';
  oldlot uuid:='06500000-0000-4000-8000-000000000003';
  oid uuid:='06500000-0000-4000-8000-000000000004';
  olid uuid:='06500000-0000-4000-8000-000000000005';
  rid uuid:='06500000-0000-4000-8000-000000000006';
  rlid uuid:='06500000-0000-4000-8000-000000000007';
  f integer; movements integer;
begin
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(tid,'2096/2097 CONTRACT 065',2096,2097,date '2096-07-01',date '2097-06-30','planificacion');

  insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo)
  values(aid,'Articulo contract 065','CONTRACT-065','camiseta','jugador','general',true,true);

  -- Existing physical stock: 20 units already represented by a valid lot.
  insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,referencia_proveedor,cantidad_fisica,cantidad_reservada)
  values(oldlot,aid,'L',tid,'PREEXISTING-065',20,0);
  insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado)
  values(oldlot,tid,'valido');
  perform private.equipacion_recalcular_stock_legacy(tid,aid,'L');

  insert into public.equipacion_pedidos(id,temporada_id,numero,proveedor_nombre,fecha_pedido,estado)
  values(oid,tid,'P-065','Proveedor 065',current_date,'pedido');
  insert into public.equipacion_pedido_lineas(id,pedido_id,articulo_id,talla,cantidad_pedida)
  values(olid,oid,aid,'L',6);
  insert into public.equipacion_recepciones(id,pedido_id,fecha_recepcion,referencia)
  values(rid,oid,current_date,'REC-065');

  insert into public.equipacion_recepcion_lineas(id,recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada)
  values(rlid,rid,olid,6,6);

  select cantidad_fisica into f
  from public.equipacion_stock
  where temporada_id=tid and articulo_id=aid and talla='L';

  if f<>26 then
    raise exception '065 contract failed: stock 20 + accepted 6 must equal 26, got %',f;
  end if;

  if (select count(*) from public.equipacion_stock_lotes where recepcion_linea_id=rlid)<>1 then
    raise exception '065 contract failed: expected exactly one reception lot';
  end if;

  select count(*) into movements
  from public.equipacion_movimientos_stock
  where recepcion_linea_id=rlid and tipo='recepcion' and cantidad=6;
  if movements<>1 then
    raise exception '065 contract failed: expected exactly one reception movement, got %',movements;
  end if;
end $$;
rollback;

do $$
begin
  if has_function_privilege('anon','private.equipacion_aplicar_recepcion_linea()','EXECUTE')
     or has_function_privilege('authenticated','private.equipacion_aplicar_recepcion_linea()','EXECUTE') then
    raise exception '065 contract failed: internal reception stock helper exposed';
  end if;
end $$;

select '065_equipaciones_stock_lotes_authority_contract' contract,'PASS' result;
