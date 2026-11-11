-- Contract 075: binary reusable return + additional item need reuse the existing logistics/economic model.
do $$
declare src text;
begin
 if has_function_privilege('anon','private.equipacion_crear_necesidad_adicional(uuid,uuid,uuid,integer,boolean,text)','EXECUTE')
 or has_function_privilege('anon','private.equipacion_registrar_devolucion(uuid,integer,boolean,text,text)','EXECUTE') then
   raise exception '075: equipment additional/return RPC exposed to anon';
 end if;
 select pg_get_functiondef('private.equipacion_registrar_devolucion(uuid,integer,boolean,text,text)'::regprocedure) into src;
 if position('DEVOLUCION:' in src)=0 then raise exception '075: reusable return does not create traceable stock'; end if;
end $$;

begin;
do $$
declare
 tid uuid:='07500000-0000-4000-8000-000000000001';
 pid uuid:='07500000-0000-4000-8000-000000000002';
 jid uuid:='07500000-0000-4000-8000-000000000003';
 pt uuid:='07500000-0000-4000-8000-000000000004';
 art uuid:='07500000-0000-4000-8000-000000000005';
 need uuid:='07500000-0000-4000-8000-000000000006';
 n integer;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2087/2088 CONTRACT 075',2087,2088,date '2087-07-01',date '2088-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract075',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo)
 values(art,'ART-075','Sudadera 075','sudadera',true,true);
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid,tid,'3XS',now());
 insert into public.equipacion_articulo_precios_temporada(temporada_id,articulo_id,precio)
 values(tid,art,30);

 -- Structural check: additional demand is a single article and price is snapshotted.
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,
   articulo_id_adicional,cantidad_adicional,sin_cargo,precio_unitario_snapshot,estado,origen,confirmada_at,comunicada_at)
 values(need,pid,tid,'jugador',jid,pt,art,2,false,30,'comunicada','manual',now(),now());
 insert into public.equipacion_asignaciones(necesidad_id,articulo_id,talla,cantidad,estado,origen)
 values(need,art,'3XS',2,'propuesta','manual');
 select count(*) into n from public.equipacion_demanda_logistica where necesidad_id=need and articulo_id=art and talla='3XS' and cantidad_demandada=2;
 if n<>1 then raise exception '075: additional single-item need is not in logistics demand'; end if;
end $$;
rollback;
select '075_devoluciones_necesidades_adicionales_contract' contract,'PASS' result;
