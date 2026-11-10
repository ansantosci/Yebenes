-- Contract 068: active sibling groups contain one row per active player.
begin;
do $$
declare
 tid uuid:='06800000-0000-4000-8000-000000000001';
 cat uuid:='06800000-0000-4000-8000-000000000002';
 eq uuid:='06800000-0000-4000-8000-000000000003';
 p1 uuid:='06800000-0000-4000-8000-000000000004';
 p2 uuid:='06800000-0000-4000-8000-000000000005';
 tut uuid:='06800000-0000-4000-8000-000000000006';
 j1 uuid:='06800000-0000-4000-8000-000000000007';
 j2 uuid:='06800000-0000-4000-8000-000000000008';
 i1 uuid:='06800000-0000-4000-8000-000000000009';
 i2 uuid:='06800000-0000-4000-8000-000000000010';
 n integer;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2093/2094 CONTRACT 068',2093,2094,date '2093-07-01',date '2094-06-30','planificacion');
 insert into public.categorias(id,codigo,nombre,orden,activo) values(cat,'C068','Categoria 068',68,true);
 insert into public.reglas_categoria_temporada(temporada_id,categoria_id,activo) values(tid,cat,true);
 insert into public.equipos(id,temporada_id,categoria_id,nombre,codigo,activo) values(eq,tid,cat,'Equipo 068','E068',true);
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo) values
 (p1,'Hermano1','Contract068',date '2015-01-01',true),
 (p2,'Hermano2','Contract068',date '2016-01-01',true),
 (tut,'Tutor','Contract068',date '1980-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(j1,p1,true,current_date),(j2,p2,true,current_date);
 insert into public.representaciones_jugador(id,jugador_id,representante_persona_id,fecha_desde,motivo_alta) values
 ('06800000-0000-4000-8000-000000000011',j1,tut,current_date,'Contract 068'),
 ('06800000-0000-4000-8000-000000000012',j2,tut,current_date,'Contract 068');
 insert into public.inscripciones(id,jugador_id,temporada_id,categoria_id,estado) values
 (i1,j1,tid,cat,'datos_validados'),(i2,j2,tid,cat,'datos_validados');
 insert into public.persona_participaciones_temporada(id,persona_id,temporada_id,faceta,origen,estado,categoria_prevista_id,aceptada_at) values
 ('06800000-0000-4000-8000-000000000013',p1,tid,'jugador','administrativa','aceptada',cat,now()),
 ('06800000-0000-4000-8000-000000000014',p2,tid,'jugador','administrativa','aceptada',cat,now());
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde) values
 ('06800000-0000-4000-8000-000000000015',i1,eq,current_date-1),
 ('06800000-0000-4000-8000-000000000016',i2,eq,current_date);

 select count(*) into n from private.economia_hermanos_activos(p1,tid);
 if n<>2 then raise exception '068: expected exactly 2 active siblings, got %',n; end if;
 if exists(select jugador_id from private.economia_hermanos_activos(p1,tid) group by jugador_id having count(*)<>1) then
   raise exception '068: duplicate active sibling row detected';
 end if;
 if (select count(*) from private.economia_hermanos_activos(p2,tid))<>2 then
   raise exception '068: sibling group must be symmetric';
 end if;
end $$;
rollback;
select '068_hermanos_activos_dedup_contract' contract,'PASS' result;
