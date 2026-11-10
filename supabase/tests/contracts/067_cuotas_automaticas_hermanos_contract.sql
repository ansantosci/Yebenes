-- Contract 067: fee hierarchy, pending configuration, idempotent team changes and active-sibling discount loss.
begin;
do $$
declare
 tid uuid:='06700000-0000-4000-8000-000000000001'; cat uuid:='06700000-0000-4000-8000-000000000002';
 ea uuid:='06700000-0000-4000-8000-000000000003'; eb uuid:='06700000-0000-4000-8000-000000000004'; ec uuid:='06700000-0000-4000-8000-000000000005';
 p1 uuid:='06700000-0000-4000-8000-000000000006'; p2 uuid:='06700000-0000-4000-8000-000000000007'; tutor uuid:='06700000-0000-4000-8000-000000000008';
 j1 uuid:='06700000-0000-4000-8000-000000000009'; j2 uuid:='06700000-0000-4000-8000-000000000010';
 i1 uuid:='06700000-0000-4000-8000-000000000011'; i2 uuid:='06700000-0000-4000-8000-000000000012';
 a1 uuid:='06700000-0000-4000-8000-000000000013'; a2 uuid:='06700000-0000-4000-8000-000000000014';
 pt1 uuid:='06700000-0000-4000-8000-000000000015'; pt2 uuid:='06700000-0000-4000-8000-000000000016';
 cid1 uuid; cid2 uuid; r record;
begin
 insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado) values(tid,'2094/2095 CONTRACT 067',2094,2095,date '2094-07-01',date '2095-06-30','planificacion');
 insert into public.categorias(id,codigo,nombre,orden,activo) values(cat,'C067','Categoria 067',67,true);
 insert into public.reglas_categoria_temporada(temporada_id,categoria_id,activo) values(tid,cat,true);
 insert into public.equipos(id,temporada_id,categoria_id,nombre,codigo,activo) values
 (ea,tid,cat,'Equipo A 067','A067',true),(eb,tid,cat,'Equipo B 067','B067',true),(ec,tid,cat,'Equipo C 067','C067',true);
 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo) values
 (p1,'Hermano1','Contract067',date '2015-01-01',true),(p2,'Hermano2','Contract067',date '2016-01-01',true),(tutor,'Tutor','Contract067',date '1980-01-01',true);
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values(j1,p1,true,current_date),(j2,p2,true,current_date);
 -- Both players are minors: create the shared active legal representative before inscription.
 -- This both satisfies the domain guard and exercises automatic sibling detection by shared tutor.
 insert into public.representaciones_jugador(id,jugador_id,representante_persona_id,fecha_desde,motivo_alta) values
 ('06700000-0000-4000-8000-000000000019',j1,tutor,current_date,'Contract 067 shared tutor'),
 ('06700000-0000-4000-8000-000000000020',j2,tutor,current_date,'Contract 067 shared tutor');
 insert into public.inscripciones(id,jugador_id,temporada_id,categoria_id,estado) values(i1,j1,tid,cat,'datos_validados'),(i2,j2,tid,cat,'datos_validados');
 insert into public.persona_participaciones_temporada(id,persona_id,temporada_id,faceta,origen,estado,categoria_prevista_id,aceptada_at)
 values(pt1,p1,tid,'jugador','administrativa','aceptada',cat,now()),(pt2,p2,tid,'jugador','administrativa','aceptada',cat,now());

 -- No rule anywhere: assignment creates calculation state but no zero-euro charge.
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde) values(a1,i1,ea,current_date-4);
 if not exists(select 1 from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid and estado_calculo='pendiente_configuracion') then raise exception '067: missing pending configuration state'; end if;
 if exists(select 1 from public.economia_cargos where persona_id=p1 and temporada_id=tid and clave_origen='CUOTA_TEMPORADA') then raise exception '067: missing config must not create zero fee'; end if;

 -- Category rule resolves A to 275. General added later must not overwrite category.
 insert into public.economia_cuota_categoria_config(temporada_id,categoria_id,importe) values(tid,cat,275);
 select cargo_id into cid1 from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid;
 select * into r from public.economia_estado_cargos where cargo_id=cid1;
 if r.importe_exigible<>275 then raise exception '067: category fee expected 275 got %',r.importe_exigible; end if;
 insert into public.economia_cuota_temporada_config(temporada_id,importe_general) values(tid,300);
 if (select importe_objetivo from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid)<>275 then raise exception '067: general fee overwrote category exception'; end if;

 -- Team C overrides category with 250. B inherits category 275. A->B must not duplicate fee; B->C regularises same fee.
 insert into public.economia_cuota_equipo_config(temporada_id,equipo_id,importe) values(tid,ec,250);
 update public.asignaciones_jugador_equipo set fecha_hasta=current_date-3 where id=a1;
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde) values('06700000-0000-4000-8000-000000000017',i1,eb,current_date-2);
 if (select count(*) from public.economia_cargos where persona_id=p1 and temporada_id=tid and clave_origen='CUOTA_TEMPORADA')<>1 then raise exception '067: A->B duplicated season fee'; end if;
 update public.asignaciones_jugador_equipo set fecha_hasta=current_date-1 where id='06700000-0000-4000-8000-000000000017';
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde) values('06700000-0000-4000-8000-000000000018',i1,ec,current_date);
 if (select importe_objetivo from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid)<>250 then raise exception '067: team exception expected 250'; end if;
 select * into r from public.economia_estado_cargos where cargo_id=cid1;
 if r.importe_exigible<>250 then raise exception '067: same fee not regularised to 250'; end if;

 -- Second active sibling, shared tutor only, gets configured position-2 discount.
 insert into public.economia_descuento_hermanos_reglas(temporada_id,posicion,tipo,valor) values(tid,2,'fijo',50);
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde) values(a2,i2,eb,current_date);
 select cargo_id into cid2 from public.economia_cuota_estado where persona_id=p2 and temporada_id=tid;
 if (select count(*) from private.economia_hermanos_activos(p1,tid))<>2 then
   raise exception '067: shared tutor must produce exactly two active siblings';
 end if;
 perform private.economia_recalcular_descuentos_hermanos(p1,tid,'configuracion');
 select * into r from public.economia_estado_cargos where cargo_id=cid2;
 if r.importe_exigible<>225 then raise exception '067: second active sibling expected 225 got %',r.importe_exigible; end if;

 -- First sibling leaves: sibling 2 loses eligibility, but +50 is only proposed, not charged automatically.
 update public.persona_participaciones_temporada set estado='baja',baja_at=now(),motivo_baja='Contract 067' where id=pt1;
 if not exists(select 1 from public.economia_regularizaciones_pendientes where cargo_id=cid2 and tipo='perdida_descuento_hermano' and estado='pendiente' and importe_calculado=50) then
   raise exception '067: sibling-loss regularisation proposal missing';
 end if;
 select * into r from public.economia_estado_cargos where cargo_id=cid2;
 if r.importe_exigible<>225 then raise exception '067: sibling loss must not charge before Club decision'; end if;
end $$;
rollback;

do $$ begin
 if has_function_privilege('anon','private.economia_decidir_regularizacion_hermano(uuid,boolean,text)','EXECUTE')
    or has_function_privilege('anon','private.economia_vincular_hermanos_manual(uuid,uuid,uuid,text)','EXECUTE') then
   raise exception '067: economic decision RPC exposed to anon';
 end if;
end $$;
select '067_cuotas_automaticas_hermanos_contract' contract,'PASS' result;
