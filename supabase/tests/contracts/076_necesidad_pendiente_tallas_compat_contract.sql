-- Contract 076: legacy pre-choice need remains valid; invalid mixed/empty finalized states remain blocked.
begin;
do $$
declare
 tid uuid:='07600000-0000-4000-8000-000000000001';
 pid uuid:='07600000-0000-4000-8000-000000000002';
 jid uuid:='07600000-0000-4000-8000-000000000003';
 pt uuid:='07600000-0000-4000-8000-000000000004';
 nid uuid:='07600000-0000-4000-8000-000000000005';
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2086/2087 CONTRACT 076',2086,2087,date '2086-07-01',date '2087-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract076',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid,tid,'3XS',now());

 -- This is the exact lifecycle shape that 075 accidentally rejected.
 insert into public.equipacion_necesidades(
   id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,reutiliza_entrenamiento,estado,confirmada_at)
 values(nid,pid,tid,'jugador',jid,pt,false,'pendiente_tallas',now());

 if not exists(select 1 from public.equipacion_necesidades where id=nid and pack_id is null and articulo_id_adicional is null)
 then raise exception '076: pending-size need was not accepted'; end if;
end $$;
rollback;
select '076_necesidad_pendiente_tallas_compat_contract' contract,'PASS' result;
