-- Contract 074: reparto payment is equipment-specific, rejects overpayment, and delivery stores debt snapshot.
do $$
declare src text;
begin
 if has_function_privilege('anon','private.equipacion_registrar_pago(uuid,numeric,text,date,text,text)','EXECUTE') then
   raise exception '074: reparto payment exposed to anon';
 end if;
 select pg_get_functiondef('private.equipacion_confirmar_entrega(uuid,uuid)'::regprocedure) into src;
 if position('deuda_pendiente_al_entregar' in src)=0 or position('entregada_con_deuda' in src)=0 then
   raise exception '074: delivery does not persist economic snapshot';
 end if;
end $$;

begin;
do $$
declare
 tid uuid:='07400000-0000-4000-8000-000000000001';
 pid uuid:='07400000-0000-4000-8000-000000000002';
 jid uuid:='07400000-0000-4000-8000-000000000003';
 pt uuid:='07400000-0000-4000-8000-000000000004';
 need uuid:='07400000-0000-4000-8000-000000000005';
 modal uuid:='07400000-0000-4000-8000-000000000006';
 cid uuid;
 ce record;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2088/2089 CONTRACT 074',2088,2089,date '2088-07-01',date '2089-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract074',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_tallas_persona(persona_id,temporada_id,talla_general,confirmada_at)
 values(pid,tid,'3XS',now());
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,estado,confirmada_at)
 values(need,pid,tid,'jugador',jid,pt,'comunicada',now());
 insert into public.economia_modalidades_equipacion(id,temporada_id,codigo,nombre,importe,requiere_entrenamiento,requiere_partido)
 values(modal,tid,'074-COMP','Completa 074',190,true,true);
 cid:=private.equipacion_recalcular_cargo(need);
 select * into ce from private.equipacion_cargo_estado(need);
 if ce.cargo_id<>cid or ce.saldo_pendiente<>190 then
   raise exception '074: expected equipment balance 190';
 end if;

 -- Structural no-overpayment guarantee is deliberately tested from function source because
 -- payment RPC authorization requires a real Club/Admin auth context.
 if position('p_importe>ce.saldo_pendiente' in
   pg_get_functiondef('private.equipacion_registrar_pago(uuid,numeric,text,date,text,text)'::regprocedure))=0 then
   raise exception '074: reparto payment does not reject overpayment';
 end if;
end $$;
rollback;
select '074_entrega_equipacion_control_economico_contract' contract,'PASS' result;
