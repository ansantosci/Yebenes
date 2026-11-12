-- Contract 078: operational states are derived only; quantity coverage must be complete.
do $$
begin
 if to_regclass('public.equipacion_estado_operativo') is null then raise exception '078: operational view missing'; end if;
 if has_table_privilege('anon','public.equipacion_estado_operativo','SELECT') then raise exception '078: operational view exposed to anon'; end if;
end $$;

begin;
do $$
declare
 tid uuid:='07800000-0000-4000-8000-000000000001';
 pid uuid:='07800000-0000-4000-8000-000000000002';
 jid uuid:='07800000-0000-4000-8000-000000000003';
 pt uuid:='07800000-0000-4000-8000-000000000004';
 art uuid:='07800000-0000-4000-8000-000000000005';
 need uuid:='07800000-0000-4000-8000-000000000006';
 ass uuid:='07800000-0000-4000-8000-000000000007';
 ord uuid:='07800000-0000-4000-8000-000000000008';
 r record;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2084/2085 CONTRACT 078',2084,2085,date '2084-07-01',date '2085-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract078',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo)
 values(art,'ART-078','Articulo 078','camiseta',true,true);
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid,tid,'3XS',now());
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,
   articulo_id_adicional,cantidad_adicional,sin_cargo,precio_unitario_snapshot,estado,origen,confirmada_at,comunicada_at)
 values(need,pid,tid,'jugador',jid,pt,art,2,true,0,'comunicada','manual',now(),now());
 insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
 values(ass,need,art,'3XS',2,'propuesta','manual');

 -- One free unit is not enough for quantity 2: must not say disponible.
 insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
 values(tid,art,'3XS',1,0);
 select * into r from public.equipacion_estado_operativo where asignacion_id=ass;
 if r.estado_operativo<>'pendiente_compra' or r.stock_disponible<>1 then
   raise exception '078: partial stock must remain pending purchase';
 end if;

 -- One additional formally ordered unit completes coverage: pedido_proveedor.
 insert into public.equipacion_pedidos(id,temporada_id,proveedor_nombre,fecha_pedido,estado)
 values(ord,tid,'Proveedor 078',current_date,'pedido');
 insert into public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,cantidad_pedida)
 values(ord,art,'3XS',1);
 select * into r from public.equipacion_estado_operativo where asignacion_id=ass;
 if r.estado_operativo<>'pedido_proveedor' or r.pendiente_proveedor<>1 then
   raise exception '078: stock plus supplier order should cover full quantity';
 end if;

 -- Two free units means immediately disponible.
 update public.equipacion_stock set cantidad_fisica=2 where temporada_id=tid and articulo_id=art and talla='3XS';
 select * into r from public.equipacion_estado_operativo where asignacion_id=ass;
 if r.estado_operativo<>'disponible' then raise exception '078: full free stock should be disponible'; end if;
end $$;
rollback;
select '078_equipacion_estado_operativo_contract' contract,'PASS' result;
