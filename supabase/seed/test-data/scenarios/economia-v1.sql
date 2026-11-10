-- TEST-S ECONOMIA v1: functional economy scenario over BASELINE.
begin;

-- Use two deterministic BASELINE players as siblings economically, but keep accounts independent.
create temp table econ_people on commit drop as
select j.id jugador_id,p.id persona_id,i.id inscripcion_id,i.temporada_id,
       row_number() over(order by p.id) n
from public.jugadores j
join public.personas p on p.id=j.persona_id
join public.inscripciones i on i.jugador_id=j.id
join private.test_dataset_entities e on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id
order by p.id limit 2;

do $$ begin
 if (select count(*) from econ_people)<>2 then raise exception 'ECONOMIA: expected two baseline players'; end if;
end $$;

create temp table econ_charge_ids(
  key text primary key,
  cargo_id uuid not null
) on commit drop;

-- Scenario-specific equipment economic modalities.
insert into public.economia_modalidades_equipacion(id,temporada_id,codigo,nombre,importe,requiere_entrenamiento,requiere_partido)
select private.test_uuid('econ:modalidad:completa'),temporada_id,'TEST-COMPLETA','Completa TEST',190,true,true from econ_people where n=1
on conflict(temporada_id,codigo) do update set importe=190,requiere_entrenamiento=true,requiere_partido=true,activo=true;
insert into public.economia_modalidades_equipacion(id,temporada_id,codigo,nombre,importe,requiere_entrenamiento,requiere_partido)
select private.test_uuid('econ:modalidad:reutiliza'),temporada_id,'TEST-REUTILIZA','Reutiliza entrenamiento TEST',35,false,true from econ_people where n=1
on conflict(temporada_id,codigo) do update set importe=35,requiere_entrenamiento=false,requiere_partido=true,activo=true;

-- Season fee: older sibling 250, younger sibling same base with a -50 sibling discount.
insert into public.economia_cargos(id,persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,inscripcion_id,clave_origen)
select private.test_uuid('econ:cuota:'||n),persona_id,temporada_id,c.id,250,'Cuota temporada TEST','asignacion_equipo',inscripcion_id,'CUOTA_TEMPORADA'
from econ_people cross join lateral (select id from public.economia_conceptos where codigo='CUOTA_TEMPORADA') c
on conflict(persona_id,temporada_id) where clave_origen='CUOTA_TEMPORADA'
do update set importe_base=excluded.importe_base,descripcion=excluded.descripcion,estado='activo',updated_at=now();

insert into econ_charge_ids(key,cargo_id)
select 'cuota:'||ep.n,c.id
from econ_people ep
join public.economia_cargos c on c.persona_id=ep.persona_id and c.temporada_id=ep.temporada_id and c.clave_origen='CUOTA_TEMPORADA';

insert into public.economia_ajustes(id,cargo_id,tipo,importe,nombre,motivo,origen)
values(private.test_uuid('econ:ajuste:hermano'),(select cargo_id from econ_charge_ids where key='cuota:2'),'descuento',-50,'Segundo hermano','Descuento temporada TEST','automatico')
on conflict(id) do nothing;

-- Partial payment only on sibling 1. It must never affect sibling 2.
insert into public.economia_pagos(id,cargo_id,importe,metodo,fecha_pago,registrado_por,observaciones)
select private.test_uuid('econ:pago:cuota1'),(select cargo_id from econ_charge_ids where key='cuota:1'),100,'efectivo',current_date,p.auth_user_id,'Pago parcial TEST'
from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
where p.auth_user_id is not null order by (r.codigo='administrador') desc limit 1
on conflict(id) do nothing;

-- Formal team-price change is a regularisation on the same fee, not a second fee.
insert into public.economia_ajustes(id,cargo_id,tipo,importe,nombre,motivo,origen)
values(private.test_uuid('econ:ajuste:cambio-equipo'),(select cargo_id from econ_charge_ids where key='cuota:1'),'regularizacion',25,'Cambio de equipo','Cuota objetivo 250 -> 275','automatico')
on conflict(id) do nothing;

-- Equipment economics: sibling 1 complete 190, sibling 2 reuse 35.
insert into public.economia_cargos(id,persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,inscripcion_id,clave_origen)
select private.test_uuid('econ:equip:'||n),persona_id,temporada_id,c.id,
       case n when 1 then 190 else 35 end,
       case n when 1 then 'Equipacion completa TEST' else 'Solo partido TEST' end,
       'equipacion',inscripcion_id,'EQUIPACION_TEST_'||n
from econ_people cross join lateral (select id from public.economia_conceptos where codigo='EQUIPACION') c
on conflict(temporada_id,persona_id,clave_origen) where clave_origen is not null
do update set importe_base=excluded.importe_base,descripcion=excluded.descripcion,estado='activo',updated_at=now();

insert into econ_charge_ids(key,cargo_id)
select 'equip:'||ep.n,c.id
from econ_people ep
join public.economia_cargos c on c.persona_id=ep.persona_id and c.temporada_id=ep.temporada_id
 and c.clave_origen='EQUIPACION_TEST_'||ep.n;

insert into public.economia_cargo_equipacion(cargo_id,modalidad_id)
values
((select cargo_id from econ_charge_ids where key='equip:1'),private.test_uuid('econ:modalidad:completa')),
((select cargo_id from econ_charge_ids where key='equip:2'),private.test_uuid('econ:modalidad:reutiliza'))
on conflict(cargo_id) do update set modalidad_id=excluded.modalidad_id;

-- Manual charge is explicit before its payment.
insert into public.economia_cargos(id,persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,clave_origen)
select private.test_uuid('econ:manual:1'),persona_id,temporada_id,c.id,30,'Torneo TEST','manual','MANUAL_TORNEO_TEST'
from econ_people cross join lateral (select id from public.economia_conceptos where codigo='OTRO') c where n=1
on conflict(temporada_id,persona_id,clave_origen) where clave_origen is not null
do update set importe_base=30,descripcion='Torneo TEST',estado='activo',updated_at=now();

insert into econ_charge_ids(key,cargo_id)
select 'manual:1',c.id from econ_people ep
join public.economia_cargos c on c.persona_id=ep.persona_id and c.temporada_id=ep.temporada_id and c.clave_origen='MANUAL_TORNEO_TEST'
where ep.n=1;

insert into public.economia_pagos(id,cargo_id,importe,metodo,fecha_pago,registrado_por)
select private.test_uuid('econ:pago:manual1'),(select cargo_id from econ_charge_ids where key='manual:1'),30,'efectivo',current_date,p.auth_user_id
from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
where p.auth_user_id is not null limit 1 on conflict(id) do nothing;

-- Overpayment / subsequent price reduction creates a credit for the same person.
insert into public.economia_pagos(id,cargo_id,importe,metodo,fecha_pago,registrado_por)
select private.test_uuid('econ:pago:equip2'),(select cargo_id from econ_charge_ids where key='equip:2'),35,'efectivo',current_date,p.auth_user_id
from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
where p.auth_user_id is not null limit 1 on conflict(id) do nothing;
insert into public.economia_ajustes(id,cargo_id,tipo,importe,nombre,motivo,origen)
values(private.test_uuid('econ:ajuste:equip2-credit'),(select cargo_id from econ_charge_ids where key='equip:2'),'regularizacion',-10,'Regularizacion TEST','Cambio aceptado antes de entrega','manual')
on conflict(id) do nothing;

-- Register every scenario entity so RESET is deterministic.
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values
('TEST-S','economia_modalidades_equipacion',private.test_uuid('econ:modalidad:completa')),
('TEST-S','economia_modalidades_equipacion',private.test_uuid('econ:modalidad:reutiliza')),
('TEST-S','economia_ajustes',private.test_uuid('econ:ajuste:hermano')),
('TEST-S','economia_pagos',private.test_uuid('econ:pago:cuota1')),
('TEST-S','economia_ajustes',private.test_uuid('econ:ajuste:cambio-equipo')),
('TEST-S','economia_cargo_equipacion',private.test_uuid('econ:equip:1')),
('TEST-S','economia_cargo_equipacion',private.test_uuid('econ:equip:2')),
('TEST-S','economia_pagos',private.test_uuid('econ:pago:manual1')),
('TEST-S','economia_pagos',private.test_uuid('econ:pago:equip2')),
('TEST-S','economia_ajustes',private.test_uuid('econ:ajuste:equip2-credit'))
on conflict do nothing;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','economia_cargos',cargo_id from econ_charge_ids
on conflict do nothing;

-- Functional assertions.
do $$
declare a record; b record; e1 record; e2 record; m record; p1 uuid; p2 uuid;
begin
 select persona_id into p1 from econ_people where n=1;
 select persona_id into p2 from econ_people where n=2;

 select * into a from public.economia_estado_cargos where cargo_id=(select cargo_id from econ_charge_ids where key='cuota:1');
 if a.importe_exigible<>275 or a.importe_pagado<>100 or a.saldo_pendiente<>175 or a.estado_pago<>'parcialmente_pagado' then
   raise exception 'ECONOMIA: sibling 1 fee incorrect';
 end if;
 select * into b from public.economia_estado_cargos where cargo_id=(select cargo_id from econ_charge_ids where key='cuota:2');
 if b.importe_exigible<>200 or b.importe_pagado<>0 or b.saldo_pendiente<>200 or b.estado_pago<>'pendiente' then
   raise exception 'ECONOMIA: sibling 2 fee/discount incorrect';
 end if;
 if (select count(*) from public.economia_cargos where persona_id=p1 and temporada_id=a.temporada_id and clave_origen='CUOTA_TEMPORADA')<>1 then
   raise exception 'ECONOMIA: team change duplicated season fee';
 end if;

 select * into e1 from public.economia_estado_cargos where cargo_id=(select cargo_id from econ_charge_ids where key='equip:1');
 select * into e2 from public.economia_estado_cargos where cargo_id=(select cargo_id from econ_charge_ids where key='equip:2');
 if e1.importe_exigible<>190 or e1.importe_pagado<>0 then raise exception 'ECONOMIA: complete equipment incorrect'; end if;
 if e2.importe_exigible<>25 or e2.importe_pagado<>35 or e2.saldo_pendiente<>-10 then raise exception 'ECONOMIA: same-person credit incorrect'; end if;

 select * into m from public.economia_estado_cargos where cargo_id=(select cargo_id from econ_charge_ids where key='manual:1');
 if m.importe_exigible<>30 or m.importe_pagado<>30 or m.estado_pago<>'pagado' then raise exception 'ECONOMIA: manual charge/payment incorrect'; end if;

 -- Payment on sibling 1 must not appear in sibling 2 account.
 if exists(select 1 from public.economia_pagos pg join public.economia_cargos c on c.id=pg.cargo_id
           where c.persona_id=p2 and pg.id=private.test_uuid('econ:pago:cuota1')) then
   raise exception 'ECONOMIA: cross-sibling payment detected';
 end if;
end $$;


-- 067/068 functional integration on isolated players: hierarchy, unresolved moves and active siblings.
do $$
declare
 tid uuid; cat uuid; ea uuid; eb uuid; ec uuid;
 p1 uuid:=private.test_uuid('econ067:p1'); p2 uuid:=private.test_uuid('econ067:p2'); tp uuid:=private.test_uuid('econ067:tutor');
 j1 uuid:=private.test_uuid('econ067:j1'); j2 uuid:=private.test_uuid('econ067:j2');
 i1 uuid:=private.test_uuid('econ067:i1'); i2 uuid:=private.test_uuid('econ067:i2');
 pt1 uuid:=private.test_uuid('econ067:pt1'); pt2 uuid:=private.test_uuid('econ067:pt2');
 a1 uuid:=private.test_uuid('econ067:a1'); a2 uuid:=private.test_uuid('econ067:a2');
 cid1 uuid; cid2 uuid; r record;
begin
 select ep.temporada_id into tid from econ_people ep where ep.n=1;
 select i.categoria_id into cat from econ_people ep join public.inscripciones i on i.id=ep.inscripcion_id where ep.n=1;
 select e.id into ea from public.equipos e where e.temporada_id=tid and e.categoria_id=cat and e.activo order by e.id limit 1;
 select e.id into eb from public.equipos e where e.temporada_id=tid and e.categoria_id=cat and e.activo and e.id<>ea order by e.id limit 1;
 if ea is null then raise exception 'ECONOMIA 067: no active team for baseline category'; end if;
 if eb is null then eb:=ea; end if;
 ec:=private.test_uuid('econ067:team:c');
 insert into public.equipos(id,temporada_id,categoria_id,nombre,codigo,activo)
 values(ec,tid,cat,'ECONOMIA 067 C','E067C',true)
 on conflict(id) do update set activo=true;

 insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo) values
 (p1,'Hermano1','ECONOMIA067',date '2015-01-01',true),
 (p2,'Hermano2','ECONOMIA067',date '2016-01-01',true),
 (tp,'Tutor','ECONOMIA067',date '1980-01-01',true)
 on conflict(id) do update set activo=true;
 insert into public.jugadores(id,persona_id,activo,fecha_alta) values
 (j1,p1,true,current_date),(j2,p2,true,current_date)
 on conflict(id) do update set activo=true;
 insert into public.representaciones_jugador(id,jugador_id,representante_persona_id,fecha_desde,motivo_alta) values
 (private.test_uuid('econ067:r1'),j1,tp,current_date,'ECONOMIA 067 shared tutor'),
 (private.test_uuid('econ067:r2'),j2,tp,current_date,'ECONOMIA 067 shared tutor')
 on conflict(id) do nothing;
 insert into public.inscripciones(id,jugador_id,temporada_id,categoria_id,estado) values
 (i1,j1,tid,cat,'datos_validados'),(i2,j2,tid,cat,'datos_validados')
 on conflict(id) do update set estado='datos_validados';
 insert into public.persona_participaciones_temporada(id,persona_id,temporada_id,faceta,origen,estado,categoria_prevista_id,aceptada_at) values
 (pt1,p1,tid,'jugador','administrativa','aceptada',cat,now()),
 (pt2,p2,tid,'jugador','administrativa','aceptada',cat,now())
 on conflict(persona_id,temporada_id,faceta) do update set estado='aceptada',baja_at=null,motivo_baja=null;

 -- Register roots immediately so interrupted runs remain repairable.
 insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values
 ('TEST-S','equipos',ec),
 ('TEST-S','personas',p1),('TEST-S','personas',p2),('TEST-S','personas',tp),
 ('TEST-S','jugadores',j1),('TEST-S','jugadores',j2),
 ('TEST-S','representaciones_jugador',private.test_uuid('econ067:r1')),('TEST-S','representaciones_jugador',private.test_uuid('econ067:r2')),
 ('TEST-S','inscripciones',i1),('TEST-S','inscripciones',i2),
 ('TEST-S','persona_participaciones_temporada',pt1),('TEST-S','persona_participaciones_temporada',pt2)
 on conflict do nothing;

 -- Remove any fee configuration inherited from the earlier 066 fixture for this category/season.
 delete from public.economia_cuota_equipo_config where temporada_id=tid and equipo_id in (ea,eb,ec);
 delete from public.economia_cuota_categoria_config where temporada_id=tid and categoria_id=cat;
 delete from public.economia_cuota_temporada_config where temporada_id=tid;

 -- No rule anywhere: assignment creates state, but never a false zero-euro charge.
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde) values(a1,i1,ea,current_date-5);
 insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','asignaciones_jugador_equipo',a1) on conflict do nothing;
 if not exists(select 1 from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid and estado_calculo='pendiente_configuracion') then
   raise exception 'ECONOMIA 067: expected pending configuration';
 end if;
 if exists(select 1 from public.economia_cargos where persona_id=p1 and temporada_id=tid and clave_origen='CUOTA_TEMPORADA') then
   raise exception 'ECONOMIA 067: missing configuration created a fee';
 end if;

 -- Category 275 resolves; adding general 300 later must not overwrite category.
 insert into public.economia_cuota_categoria_config(temporada_id,categoria_id,importe) values(tid,cat,275);
 select cargo_id into cid1 from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid;
 if cid1 is null then raise exception 'ECONOMIA 067: category rule did not consolidate fee'; end if;
 insert into public.economia_cuota_temporada_config(temporada_id,importe_general) values(tid,300);
 if (select importe_objetivo from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid)<>275 then
   raise exception 'ECONOMIA 067: general fee overwrote category exception';
 end if;

 -- Move from known fee to unresolved destination: remove inherited rules before C assignment.
 update public.asignaciones_jugador_equipo set fecha_hasta=current_date-4 where id=a1;
 delete from public.economia_cuota_categoria_config where temporada_id=tid and categoria_id=cat;
 delete from public.economia_cuota_temporada_config where temporada_id=tid;
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde)
 values(private.test_uuid('econ067:c-pending'),i1,ec,current_date-3);
 insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
 values('TEST-S','asignaciones_jugador_equipo',private.test_uuid('econ067:c-pending')) on conflict do nothing;
 if (select estado_calculo from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid)<>'pendiente_configuracion' then
   raise exception 'ECONOMIA 067: unresolved destination not pending';
 end if;
 select * into r from public.economia_estado_cargos where cargo_id=cid1;
 if r.importe_exigible<>275 then raise exception 'ECONOMIA 067: unresolved destination changed consolidated fee'; end if;

 -- Team C 250 resolves the pending move on the same charge.
 insert into public.economia_cuota_equipo_config(temporada_id,equipo_id,importe) values(tid,ec,250);
 if (select importe_objetivo from public.economia_cuota_estado where persona_id=p1 and temporada_id=tid)<>250 then
   raise exception 'ECONOMIA 067: team exception expected 250';
 end if;
 if (select count(*) from public.economia_cargos where persona_id=p1 and temporada_id=tid and clave_origen='CUOTA_TEMPORADA')<>1 then
   raise exception 'ECONOMIA 067: move duplicated season fee';
 end if;

 -- Second sibling: category 275, position 2 fixed discount 50.
 insert into public.economia_cuota_categoria_config(temporada_id,categoria_id,importe) values(tid,cat,275);
 insert into public.economia_descuento_hermanos_reglas(temporada_id,posicion,tipo,valor) values(tid,2,'fijo',50)
 on conflict(temporada_id,posicion) do update set tipo='fijo',valor=50,activo=true;
 insert into public.asignaciones_jugador_equipo(id,inscripcion_id,equipo_id,fecha_desde) values(a2,i2,ea,current_date-2);
 insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','asignaciones_jugador_equipo',a2) on conflict do nothing;
 select cargo_id into cid2 from public.economia_cuota_estado where persona_id=p2 and temporada_id=tid;
 perform private.economia_recalcular_descuentos_hermanos(p1,tid,'configuracion');
 if (select count(*) from private.economia_hermanos_activos(p1,tid))<>2 then
   raise exception 'ECONOMIA 068: shared tutor must yield exactly two active siblings';
 end if;
 select * into r from public.economia_estado_cargos where cargo_id=cid2;
 if r.importe_exigible<>225 then raise exception 'ECONOMIA 067: second sibling expected 225 got %',r.importe_exigible; end if;

 -- First sibling leaves: +50 is proposed, not charged automatically.
 update public.persona_participaciones_temporada set estado='baja',baja_at=now(),motivo_baja='ECONOMIA 067'
 where id=pt1;
 if not exists(select 1 from public.economia_regularizaciones_pendientes
               where cargo_id=cid2 and tipo='perdida_descuento_hermano' and estado='pendiente' and importe_calculado=50) then
   raise exception 'ECONOMIA 067: missing sibling-loss proposal';
 end if;
 select * into r from public.economia_estado_cargos where cargo_id=cid2;
 if r.importe_exigible<>225 then raise exception 'ECONOMIA 067: proposal charged before Club decision'; end if;

 -- Register generated economic rows for repair-safe reset.
 insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
 select 'TEST-S','economia_cargos',c.id from public.economia_cargos c
 where c.persona_id in (p1,p2) and c.temporada_id=tid
 on conflict do nothing;
 insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
 select 'TEST-S','economia_ajustes',a.id from public.economia_ajustes a
 join public.economia_cargos c on c.id=a.cargo_id
 where c.persona_id in (p1,p2) and c.temporada_id=tid
 on conflict do nothing;
 insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
 select 'TEST-S','economia_regularizaciones_pendientes',rp.id from public.economia_regularizaciones_pendientes rp
 where rp.persona_id in (p1,p2) and rp.temporada_id=tid
 on conflict do nothing;
end $$;

update private.test_datasets set scenario='ECONOMIA',loaded_at=now(),
 metadata='{"purpose":"functional economy scenario","version":"v1"}'::jsonb where id='TEST-S';
commit;
