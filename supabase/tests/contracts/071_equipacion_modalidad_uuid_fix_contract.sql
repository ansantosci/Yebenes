-- Contract 071: modality resolver is UUID-safe and rejects ambiguous configuration.
do $$
declare src text;
begin
 select pg_get_functiondef('private.equipacion_resolver_modalidad_economica(uuid)'::regprocedure) into src;
 if position('min(m.id)' in lower(src))>0 or position('min(id)' in lower(src))>0 then
   raise exception '071: UUID resolver still uses min(uuid)';
 end if;
 if position('select count(*) into cnt' in lower(src))=0 then
   raise exception '071: resolver must count candidates explicitly';
 end if;
end $$;

begin;
do $$
declare
 tid uuid:='07100000-0000-4000-8000-000000000001'; pid uuid:='07100000-0000-4000-8000-000000000002';
 jid uuid:='07100000-0000-4000-8000-000000000003'; pt uuid:='07100000-0000-4000-8000-000000000004';
 talla uuid:='07100000-0000-4000-8000-000000000005'; need uuid:='07100000-0000-4000-8000-000000000006';
 m1 uuid:='07100000-0000-4000-8000-000000000007'; m2 uuid:='07100000-0000-4000-8000-000000000008';
 got uuid; failed boolean:=false;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2091/2092 CONTRACT 071',2091,2092,date '2091-07-01',date '2092-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract071',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_tallas_persona(id,persona_id,temporada_id,talla_general,aplica_todas,confirmada_at)
 values(talla,pid,tid,'3XS',true,now());
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,reutiliza_entrenamiento,estado,confirmada_at)
 values(need,pid,tid,'jugador',jid,pt,false,'comunicada',now());

 -- zero candidates
 begin
   perform private.equipacion_resolver_modalidad_economica(need);
 exception when others then
   failed:=position('No economic equipment modality' in sqlerrm)>0;
 end;
 if not failed then raise exception '071: zero modality configuration must fail'; end if;

 -- exactly one candidate returns that UUID
 insert into public.economia_modalidades_equipacion(id,temporada_id,codigo,nombre,importe,requiere_entrenamiento,requiere_partido)
 values(m1,tid,'ONE-071','One',190,true,true);
 got:=private.equipacion_resolver_modalidad_economica(need);
 if got<>m1 then raise exception '071: expected modality %, got %',m1,got; end if;

 -- two candidates are ambiguous
 insert into public.economia_modalidades_equipacion(id,temporada_id,codigo,nombre,importe,requiere_entrenamiento,requiere_partido)
 values(m2,tid,'TWO-071','Two',195,true,true);
 failed:=false;
 begin
   perform private.equipacion_resolver_modalidad_economica(need);
 exception when others then
   failed:=position('Ambiguous economic equipment modality' in sqlerrm)>0;
 end;
 if not failed then raise exception '071: ambiguous modality configuration must fail'; end if;
end $$;
rollback;
select '071_equipacion_modalidad_uuid_fix_contract' contract,'PASS' result;
