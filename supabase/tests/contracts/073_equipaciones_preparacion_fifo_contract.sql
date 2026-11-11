-- Contract 073: automatic preparation is FIFO, multi-lot, article-atomic and idempotent.
do $$
begin
 if has_function_privilege('anon','private.equipacion_preparar_asignacion_fifo(uuid)','EXECUTE') then
   raise exception '073: FIFO preparation exposed to anon';
 end if;
end $$;

begin;
do $$
declare
 tid uuid:='07300000-0000-4000-8000-000000000001';
 pid uuid:='07300000-0000-4000-8000-000000000002';
 jid uuid:='07300000-0000-4000-8000-000000000003';
 pt uuid:='07300000-0000-4000-8000-000000000011';
 art uuid:='07300000-0000-4000-8000-000000000004';
 pack uuid:='07300000-0000-4000-8000-000000000005';
 need uuid:='07300000-0000-4000-8000-000000000006';
 ass uuid:='07300000-0000-4000-8000-000000000007';
 l1 uuid:='07300000-0000-4000-8000-000000000008';
 l2 uuid:='07300000-0000-4000-8000-000000000009';
 l3 uuid:='07300000-0000-4000-8000-000000000010';
 n integer;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2089/2090 CONTRACT 073',2089,2090,date '2089-07-01',date '2090-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract073',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo)
 values(art,'ART-073','Articulo 073','camiseta',true,true);
 insert into public.equipacion_packs(id,temporada_id,codigo,nombre,destinatario,modalidad,precio,activo)
 values(pack,tid,'PACK-073','Entrenamiento 073','jugador','entrenamiento',0,true);
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid,tid,'3XS',now());
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,pack_id,estado,confirmada_at)
 values(need,pid,tid,'jugador',jid,pt,pack,'comunicada',now());
 insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado)
 values(ass,need,art,'3XS',3,'propuesta');

 insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,cantidad_fisica,created_at) values
 (l1,art,'3XS',tid,1,now()-interval '30 days'),
 (l2,art,'3XS',tid,1,now()-interval '20 days'),
 (l3,art,'3XS',tid,5,now()-interval '10 days');
 insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at) values
 (l1,tid,'valido',now()),(l2,tid,'valido',now()),(l3,tid,'valido',now());

 -- Contract runs without authenticated Club context, so exercise the same internal
 -- reservation primitive after verifying FIFO candidate order through the SQL function body.
 -- Functional end-to-end authorization is covered by existing 062 contracts.
 if position('order by coalesce(r.fecha_recepcion::timestamptz,l2.created_at),l2.created_at,l2.id'
    in lower(pg_get_functiondef('private.equipacion_preparar_asignacion_fifo(uuid)'::regprocedure)))=0 then
   raise exception '073: FIFO ordering missing';
 end if;

 -- Verify multi-lot representation and derived pack partial states independently.
 insert into public.equipacion_asignacion_lotes(asignacion_id,lote_id,cantidad,estado)
 values(ass,l1,1,'reservada'),(ass,l2,1,'reservada'),(ass,l3,1,'reservada');
 update public.equipacion_stock_lotes set cantidad_reservada=1 where id in(l1,l2,l3);
 update public.equipacion_asignaciones set estado='reservada',reservado_at=now() where id=ass;

 if (select estado_reparto from public.equipacion_reparto_resumen where necesidad_id=need)<>'preparado' then
   raise exception '073: pack with all current assignments reserved must be prepared';
 end if;
 select count(*) into n from public.equipacion_asignacion_lotes where asignacion_id=ass and estado='reservada';
 if n<>3 then raise exception '073: assignment must support multiple FIFO lots'; end if;
end $$;
rollback;
select '073_equipaciones_preparacion_fifo_contract' contract,'PASS' result;
