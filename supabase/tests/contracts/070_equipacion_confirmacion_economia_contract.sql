-- Contract 070: family confirmation locks request and creates/reconciles equipment debt.
do $$
begin
 if to_regclass('public.equipacion_solicitud_cambios') is null then raise exception '070: audit table missing'; end if;
 if has_function_privilege('anon','private.equipacion_confirmar_solicitud(uuid)','EXECUTE')
    or has_function_privilege('anon','private.equipacion_corregir_solicitud_confirmada(uuid,text,boolean,text)','EXECUTE') then
   raise exception '070: equipment mutation RPC exposed to anon';
 end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='equipacion_tallas_persona'
   and policyname='equipacion_tallas_write' and (qual like '%confirmada_at IS NULL%' or with_check like '%confirmada_at IS NULL%')) then
   raise exception '070: family size lock policy missing';
 end if;
end $$;

begin;
do $$
declare
 tid uuid:='07000000-0000-4000-8000-000000000001'; pid uuid:='07000000-0000-4000-8000-000000000002';
 jid uuid:='07000000-0000-4000-8000-000000000003'; pt uuid:='07000000-0000-4000-8000-000000000004';
 talla uuid:='07000000-0000-4000-8000-000000000005'; need uuid:='07000000-0000-4000-8000-000000000006';
 complete uuid:='07000000-0000-4000-8000-000000000007'; reuse uuid:='07000000-0000-4000-8000-000000000008';
 cid uuid; r record;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
 values(tid,'2092/2093 CONTRACT 070',2092,2093,date '2092-07-01',date '2093-06-30','planificacion');
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
 values(pid,'Jugador','Contract070',date '2000-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,current_date);
 insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
 values(pt,pid,tid,'jugador',jid,'validada',now());
 insert into public.equipacion_tallas_persona(id,persona_id,temporada_id,talla_general,aplica_todas)
 values(talla,pid,tid,'3XS',true);
 insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,reutiliza_entrenamiento,estado)
 values(need,pid,tid,'jugador',jid,pt,false,'pendiente_tallas');
 insert into public.economia_modalidades_equipacion(id,temporada_id,codigo,nombre,importe,requiere_entrenamiento,requiere_partido)
 values(complete,tid,'COMP-070','Completa',190,true,true),(reuse,tid,'REUSE-070','Reutiliza',35,false,true);

 -- Simulate the controlled confirmation transition without requiring auth context in contract.
 update public.equipacion_tallas_persona set confirmada_at=now() where id=talla;
 update public.equipacion_necesidades set confirmada_at=now(),comunicada_at=now(),estado='comunicada' where id=need;
 cid:=private.equipacion_recalcular_cargo(need);
 select * into r from public.economia_estado_cargos where cargo_id=cid;
 if r.importe_exigible<>190 then raise exception '070: complete request expected 190 got %',r.importe_exigible; end if;

 update public.equipacion_necesidades set reutiliza_entrenamiento=true where id=need;
 perform private.equipacion_recalcular_cargo(need);
 select * into r from public.economia_estado_cargos where cargo_id=cid;
 if r.importe_exigible<>35 then raise exception '070: reuse reconciliation expected 35 got %',r.importe_exigible; end if;
 if (select count(*) from public.economia_cargos where persona_id=pid and temporada_id=tid and clave_origen='EQUIPACION_NECESIDAD:'||need::text)<>1 then
   raise exception '070: equipment reconciliation duplicated charge';
 end if;
 if not exists(select 1 from public.economia_ajustes where cargo_id=cid and clave_origen='EQUIPACION_RECALCULO' and importe=-155) then
   raise exception '070: expected -155 equipment regularisation';
 end if;
end $$;
rollback;
select '070_equipacion_confirmacion_economia_contract' contract,'PASS' result;
