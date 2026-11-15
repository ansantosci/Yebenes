-- Contract 085: explicit multi-preparation is atomic, same person/season and frontend-callable only through public wrapper.
do $$
declare src text; pubsrc text;
begin
 if to_regprocedure('private.equipacion_preparar_multiple(uuid[])') is null then
   raise exception '085: private multi-preparation operation missing';
 end if;
 if to_regprocedure('public.equipacion_preparar_multiple(uuid[])') is null then
   raise exception '085: public multi-preparation RPC missing';
 end if;
 if has_function_privilege('anon','private.equipacion_preparar_multiple(uuid[])','EXECUTE')
    or has_function_privilege('anon','public.equipacion_preparar_multiple(uuid[])','EXECUTE') then
   raise exception '085: multi-preparation exposed to anon';
 end if;
 if not has_function_privilege('authenticated','public.equipacion_preparar_multiple(uuid[])','EXECUTE') then
   raise exception '085: authenticated cannot execute public multi-preparation RPC';
 end if;
 select pg_get_functiondef('private.equipacion_preparar_multiple(uuid[])'::regprocedure) into src;
 if position('equipacion_preparar_asignacion_fifo' in src)=0
    or position('duplicate assignments are not allowed' in lower(src))=0
    or position('same person and season' in lower(src))=0
    or position('order by a.id' in lower(src))=0
    or position('for update' in lower(src))=0 then
   raise exception '085: private atomic preparation orchestration contract missing';
 end if;
 select pg_get_functiondef('public.equipacion_preparar_multiple(uuid[])'::regprocedure) into pubsrc;
 if position('private.equipacion_preparar_multiple' in pubsrc)=0 then
   raise exception '085: public RPC does not delegate to private operation';
 end if;
end $$;

-- Deterministic fixture verifies the grouping guard inputs without invoking an authorized RPC.
begin;
do $$
declare
 tid uuid:='08500000-0000-4000-8000-000000000001';
 pid uuid:='08500000-0000-4000-8000-000000000002';
 jid uuid:='08500000-0000-4000-8000-000000000003';
 n1 uuid:='08500000-0000-4000-8000-000000000004';
 n2 uuid:='08500000-0000-4000-8000-000000000005';
 art1 uuid:='08500000-0000-4000-8000-000000000006';
 art2 uuid:='08500000-0000-4000-8000-000000000007';
 a1 uuid:='08500000-0000-4000-8000-000000000008';
 a2 uuid:='08500000-0000-4000-8000-000000000009';
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2085/2086 CONTRACT 085',2085,2086,date '2085-07-01',date '2086-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract085',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo) values
 (art1,'ART-085-A','Articulo 085 A','camiseta',true,true),
 (art2,'ART-085-B','Articulo 085 B','pantalon',true,true);
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,estado)
 values(n1,pid,tid,'jugador',jid,'pendiente_tallas'),(n2,pid,tid,'jugador',jid,'pendiente_tallas');
 insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado)
 values(a1,n1,art1,'3XS',1,'propuesta'),(a2,n2,art2,'3XS',1,'propuesta');
 if (select count(distinct n.persona_id) from public.equipacion_asignaciones a
     join public.equipacion_necesidades n on n.id=a.necesidad_id where a.id=any(array[a1,a2]))<>1
 then raise exception '085: same-person fixture invalid'; end if;
 if (select count(distinct n.temporada_id) from public.equipacion_asignaciones a
     join public.equipacion_necesidades n on n.id=a.necesidad_id where a.id=any(array[a1,a2]))<>1
 then raise exception '085: same-season fixture invalid'; end if;
end $$;
rollback;

select '085_preparacion_multiple_atomica_contract' contract,'PASS' result;
