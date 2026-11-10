-- Contract 064: an accepted reception creates exactly one traceable lot.
begin;
do $$
declare
  tid uuid:='06400000-0000-4000-8000-000000000001';
  aid uuid:='06400000-0000-4000-8000-000000000002';
  oid uuid:='06400000-0000-4000-8000-000000000003';
  olid uuid:='06400000-0000-4000-8000-000000000004';
  rid uuid:='06400000-0000-4000-8000-000000000005';
  rlid uuid:='06400000-0000-4000-8000-000000000006';
  lid uuid;
begin
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(tid,'2097/2098 CONTRACT 064',2097,2098,date '2097-07-01',date '2098-06-30','planificacion');

  insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo)
  values(aid,'Articulo contract 064','CONTRACT-064','camiseta','jugador','general',true,true);

  insert into public.equipacion_pedidos(id,temporada_id,numero,proveedor_nombre,fecha_pedido,estado)
  values(oid,tid,'P-064','Proveedor 064',current_date,'pedido');

  insert into public.equipacion_pedido_lineas(id,pedido_id,articulo_id,talla,cantidad_pedida)
  values(olid,oid,aid,'M',3);

  insert into public.equipacion_recepciones(id,pedido_id,fecha_recepcion,referencia)
  values(rid,oid,current_date,'REC-064');

  -- Existing 053 trigger and the 062/064 lot trigger both run here.
  insert into public.equipacion_recepcion_lineas(
    id,recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada)
  values(rlid,rid,olid,3,3);

  select id into lid from public.equipacion_stock_lotes where recepcion_linea_id=rlid;
  if lid is null then raise exception '064 contract failed: reception did not create traceable lot'; end if;

  if (select count(*) from public.equipacion_stock_lotes where recepcion_linea_id=rlid)<>1 then
    raise exception '064 contract failed: reception created duplicate lots';
  end if;

  if not exists(
    select 1 from public.equipacion_stock_lotes
    where id=lid and articulo_id=aid and talla='M' and temporada_origen_id=tid
      and proveedor_nombre='Proveedor 064' and referencia_proveedor='REC-064'
      and cantidad_fisica=3 and cantidad_reservada=0
  ) then raise exception '064 contract failed: traceable lot contents incorrect'; end if;

  if not exists(
    select 1 from public.equipacion_stock_lote_vigencia
    where lote_id=lid and temporada_id=tid and estado='valido'
  ) then raise exception '064 contract failed: origin-season validity missing'; end if;

  if not exists(
    select 1 from public.equipacion_stock
    where temporada_id=tid and articulo_id=aid and talla='M'
      and cantidad_fisica=3 and cantidad_reservada=0
  ) then raise exception '064 contract failed: legacy stock projection not reconciled'; end if;
end $$;
rollback;

do $$
begin
  if has_function_privilege('anon','private.equipacion_crear_lote_recepcion()','EXECUTE')
     or has_function_privilege('authenticated','private.equipacion_crear_lote_recepcion()','EXECUTE') then
    raise exception '064 contract failed: internal reception helper exposed';
  end if;
end $$;

select '064_equipaciones_recepcion_lote_conflict_fix_contract' as contract,'PASS' as result;
