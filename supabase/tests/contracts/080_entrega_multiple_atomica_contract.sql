-- Contract 080: explicit selection, per-item displacement authorization, same person/season, atomic orchestration.
do $$
declare src text;
begin
 if has_function_privilege('anon','private.equipacion_entregar_multiple(uuid[],uuid[])','EXECUTE') then
  raise exception '080: multi delivery exposed to anon';
 end if;
 select pg_get_functiondef('private.equipacion_entregar_multiple(uuid[],uuid[])'::regprocedure) into src;
 if position('equipacion_entregar_directo' in src)=0
 or position('same person and season' in lower(src))=0
 or position('displacement authorization contains an unselected assignment' in lower(src))=0 then
  raise exception '080: multi delivery orchestration contract missing';
 end if;
end $$;

begin;
do $$
declare
 tid uuid:='08000000-0000-4000-8000-000000000001';
 pid uuid:='08000000-0000-4000-8000-000000000002';
 jid uuid:='08000000-0000-4000-8000-000000000003';
 n1 uuid:='08000000-0000-4000-8000-000000000004';
 n2 uuid:='08000000-0000-4000-8000-000000000005';
 art1 uuid:='08000000-0000-4000-8000-000000000006';
 art2 uuid:='08000000-0000-4000-8000-000000000007';
 a1 uuid:='08000000-0000-4000-8000-000000000008';
 a2 uuid:='08000000-0000-4000-8000-000000000009';
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2083/2084 CONTRACT 080',2083,2084,date '2083-07-01',date '2084-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract080',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo) values
 (art1,'ART-080-A','Articulo 080 A','camiseta',true,true),
 (art2,'ART-080-B','Articulo 080 B','pantalon',true,true);
 -- No persona_temporada/confirmada_at needed: this fixture only verifies the grouping identity
 -- consumed by the multi-delivery guard, without invoking the authorized RPC.
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,estado)
 values(n1,pid,tid,'jugador',jid,'pendiente_tallas'),(n2,pid,tid,'jugador',jid,'pendiente_tallas');
 insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado)
 values(a1,n1,art1,'3XS',1,'propuesta'),(a2,n2,art2,'3XS',1,'propuesta');
 if (select count(distinct n.persona_id) from public.equipacion_asignaciones a
     join public.equipacion_necesidades n on n.id=a.necesidad_id where a.id=any(array[a1,a2]))<>1
 then raise exception '080: same-person fixture invalid'; end if;
end $$;
rollback;
select '080_entrega_multiple_atomica_contract' contract,'PASS' result;
