-- Contract 072: only confirmed demand counts and supplier-pending orders reduce purchase suggestion.
begin;
do $$
declare
 tid uuid:='07200000-0000-4000-8000-000000000001';
 pid1 uuid:='07200000-0000-4000-8000-000000000002';
 pid2 uuid:='07200000-0000-4000-8000-000000000003';
 art uuid:='07200000-0000-4000-8000-000000000004';
 pack uuid:='07200000-0000-4000-8000-000000000005';
 need1 uuid:='07200000-0000-4000-8000-000000000006';
 need2 uuid:='07200000-0000-4000-8000-000000000007';
 ord_draft uuid:='07200000-0000-4000-8000-000000000008';
 ord_sent uuid:='07200000-0000-4000-8000-000000000009';
 r record;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2090/2091 CONTRACT 072',2090,2091,date '2090-07-01',date '2091-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo) values
 (pid1,'Confirmed','Contract072',date '2000-01-01',true),
 (pid2,'Draft','Contract072',date '2000-01-01',true);
 insert into public.equipacion_articulos(id,codigo,nombre,tipo,usa_talla,activo)
 values(art,'ART-072','Articulo 072','camiseta',true,true);
 insert into public.equipacion_packs(id,temporada_id,codigo,nombre,destinatario,modalidad,precio,activo)
 values(pack,tid,'PACK-072','Pack 072','jugador','entrenamiento',0,true);
 insert into public.equipacion_pack_articulos(pack_id,articulo_id,cantidad,obligatorio)
 values(pack,art,10,true);

 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,aplica_todas,confirmada_at)
 values(pid1,tid,'3XS',true,now()),(pid2,tid,'3XS',true,null);

 -- persona_temporada_id intentionally null: these rows test the derived view boundary only.
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,pack_id,estado,confirmada_at)
 values
 (need1,pid1,tid,'jugador',pack,'comunicada',now()),
 (need2,pid2,tid,'jugador',pack,'comunicada',null);

 select * into r from public.equipacion_compra_sugerida
 where temporada_id=tid and articulo_id=art and talla='3XS';
 if r.demanda<>10 or r.demanda_confirmada<>10 or r.falta_comprar<>10 then
   raise exception '072: draft request leaked into confirmed demand';
 end if;

 -- Four physical units cover demand regardless of later individual reservation.
 insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
 values(tid,art,'3XS',4,0);
 select * into r from public.equipacion_compra_sugerida where temporada_id=tid and articulo_id=art and talla='3XS';
 if r.stock_fisico<>4 or r.stock_disponible<>4 or r.falta_comprar<>6 then
   raise exception '072: expected 10 demand - 4 physical = 6 purchase';
 end if;

 -- Draft supplier orders do not cover demand.
 insert into public.equipacion_pedidos(id,temporada_id,proveedor_nombre,fecha_pedido,estado)
 values(ord_draft,tid,'Proveedor 072',current_date,'borrador');
 insert into public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,cantidad_pedida)
 values(ord_draft,art,'3XS',2);
 select * into r from public.equipacion_compra_sugerida where temporada_id=tid and articulo_id=art and talla='3XS';
 if r.pendiente_proveedor<>0 or r.falta_comprar<>6 then
   raise exception '072: draft order must not reduce suggestion';
 end if;

 -- A formally sent order does cover pending demand.
 insert into public.equipacion_pedidos(id,temporada_id,proveedor_nombre,fecha_pedido,estado)
 values(ord_sent,tid,'Proveedor 072',current_date,'pedido');
 insert into public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,cantidad_pedida)
 values(ord_sent,art,'3XS',2);
 select * into r from public.equipacion_compra_sugerida where temporada_id=tid and articulo_id=art and talla='3XS';
 if r.pendiente_proveedor<>2 or r.falta_comprar<>4 then
   raise exception '072: sent supplier order must reduce suggestion';
 end if;

 -- Reserving existing stock must not make the system buy it again.
 update public.equipacion_stock set cantidad_reservada=3 where temporada_id=tid and articulo_id=art and talla='3XS';
 select * into r from public.equipacion_compra_sugerida where temporada_id=tid and articulo_id=art and talla='3XS';
 if r.stock_disponible<>1 or r.falta_comprar<>4 then
   raise exception '072: reserved physical stock must still cover demand';
 end if;
end $$;
rollback;
select '072_demanda_confirmada_compra_sugerida_contract' contract,'PASS' result;
