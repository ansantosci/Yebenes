-- Contract 079: preparation is soft; direct delivery can explicitly displace it.
do $$
declare src text;
begin
 if has_function_privilege('anon','private.equipacion_entregar_directo(uuid,boolean)','EXECUTE') then
  raise exception '079: direct delivery exposed to anon';
 end if;
 select pg_get_functiondef('private.equipacion_entregar_directo(uuid,boolean)'::regprocedure) into src;
 if position('equipacion_preparaciones_desplazadas' in src)=0
 or position('order by al.reservado_at desc' in lower(src))=0
 or position('equipacion_preparar_asignacion_fifo' in src)=0
 or position('equipacion_confirmar_entrega' in src)=0 then
  raise exception '079: direct delivery does not preserve soft-preparation/FIFO/delivery chain';
 end if;
end $$;

begin;
do $$
declare
 tid uuid:='07900000-0000-4000-8000-000000000001';
 pid1 uuid:='07900000-0000-4000-8000-000000000002';
 pid2 uuid:='07900000-0000-4000-8000-000000000003';
 j1 uuid:='07900000-0000-4000-8000-000000000004';
 j2 uuid:='07900000-0000-4000-8000-000000000005';
 pt1 uuid:='07900000-0000-4000-8000-000000000012';
 pt2 uuid:='07900000-0000-4000-8000-000000000013';
 art uuid:='07900000-0000-4000-8000-000000000006';
 l uuid:='07900000-0000-4000-8000-000000000007';
 n1 uuid:='07900000-0000-4000-8000-000000000008';
 n2 uuid:='07900000-0000-4000-8000-000000000009';
 a1 uuid:='07900000-0000-4000-8000-000000000010';
 a2 uuid:='07900000-0000-4000-8000-000000000011';
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2084/2085 CONTRACT 079',2084,2085,date '2084-07-01',date '2085-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo) values
 (pid1,'Uno','Contract079',date '2000-01-01',true),(pid2,'Dos','Contract079',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(j1,pid1,true,current_date),(j2,pid2,true,current_date);
 insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo)
 values(art,'ART-079','Articulo 079','camiseta',true,true);
 insert into public.equipacion_personas_temporada(
   id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values
   (pt1,pid1,tid,'jugador',j1,'validada',now()),
   (pt2,pid2,tid,'jugador',j2,'validada',now());
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid1,tid,'3XS',now()),(pid2,tid,'3XS',now());
 insert into public.equipacion_necesidades(
   id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,estado,confirmada_at)
 values
   (n1,pid1,tid,'jugador',j1,pt1,'comunicada',now()),
   (n2,pid2,tid,'jugador',j2,pt2,'comunicada',now());
 insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,reservado_at)
 values(a1,n1,art,'3XS',1,'reservada',now()-interval '1 day'),(a2,n2,art,'3XS',1,'propuesta',null);
 insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,cantidad_fisica,cantidad_reservada)
 values(l,art,'3XS',tid,1,1);
 insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at)
 values(l,tid,'valido',now());
 insert into public.equipacion_asignacion_lotes(asignacion_id,lote_id,cantidad,estado,reservado_at)
 values(a1,l,1,'reservada',now()-interval '1 day');

 -- Representation invariant: one physical unit can be fully committed yet still physically exists.
 if (select cantidad_fisica from public.equipacion_stock_lotes where id=l)<>1
 or (select cantidad_reservada from public.equipacion_stock_lotes where id=l)<>1 then
  raise exception '079: soft preparation fixture invalid';
 end if;
end $$;
rollback;
select '079_entrega_directa_reserva_blanda_contract' contract,'PASS' result;
