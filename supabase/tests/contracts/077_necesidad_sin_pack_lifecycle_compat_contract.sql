-- Contract 077: ordinary need without pack survives pending_tallas -> comunicada.
begin;
do $$
declare
 tid uuid:='07700000-0000-4000-8000-000000000001';
 pid uuid:='07700000-0000-4000-8000-000000000002';
 jid uuid:='07700000-0000-4000-8000-000000000003';
 pt uuid:='07700000-0000-4000-8000-000000000004';
 nid uuid:='07700000-0000-4000-8000-000000000005';
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2085/2086 CONTRACT 077',2085,2086,date '2085-07-01',date '2086-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract077',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid,tid,'3XS',now());

 insert into public.equipacion_necesidades(
   id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,reutiliza_entrenamiento,estado,confirmada_at)
 values(nid,pid,tid,'jugador',jid,pt,false,'pendiente_tallas',now());

 -- Mirrors the historical 070 lifecycle that 075/076 accidentally constrained.
 update public.equipacion_necesidades
 set estado='comunicada',comunicada_at=now()
 where id=nid;

 if not exists(
   select 1 from public.equipacion_necesidades
   where id=nid and estado='comunicada' and pack_id is null
     and articulo_id_adicional is null and cantidad_adicional is null
 ) then raise exception '077: ordinary no-pack need did not survive lifecycle transition'; end if;
end $$;
rollback;
select '077_necesidad_sin_pack_lifecycle_compat_contract' contract,'PASS' result;
