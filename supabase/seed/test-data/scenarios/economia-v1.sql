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

insert into public.economia_ajustes(id,cargo_id,tipo,importe,nombre,motivo,origen)
values(private.test_uuid('econ:ajuste:hermano'),private.test_uuid('econ:cuota:2'),'descuento',-50,'Segundo hermano','Descuento temporada TEST','automatico')
on conflict(id) do nothing;

-- Partial payment only on sibling 1. It must never affect sibling 2.
insert into public.economia_pagos(id,cargo_id,importe,metodo,fecha_pago,registrado_por,observaciones)
select private.test_uuid('econ:pago:cuota1'),private.test_uuid('econ:cuota:1'),100,'efectivo',current_date,p.auth_user_id,'Pago parcial TEST'
from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
where p.auth_user_id is not null order by (r.codigo='administrador') desc limit 1
on conflict(id) do nothing;

-- Formal team-price change is a regularisation on the same fee, not a second fee.
insert into public.economia_ajustes(id,cargo_id,tipo,importe,nombre,motivo,origen)
values(private.test_uuid('econ:ajuste:cambio-equipo'),private.test_uuid('econ:cuota:1'),'regularizacion',25,'Cambio de equipo','Cuota objetivo 250 -> 275','automatico')
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

insert into public.economia_cargo_equipacion(cargo_id,modalidad_id)
values
(private.test_uuid('econ:equip:1'),private.test_uuid('econ:modalidad:completa')),
(private.test_uuid('econ:equip:2'),private.test_uuid('econ:modalidad:reutiliza'))
on conflict(cargo_id) do update set modalidad_id=excluded.modalidad_id;

-- Manual charge is explicit before its payment.
insert into public.economia_cargos(id,persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,clave_origen)
select private.test_uuid('econ:manual:1'),persona_id,temporada_id,c.id,30,'Torneo TEST','manual','MANUAL_TORNEO_TEST'
from econ_people cross join lateral (select id from public.economia_conceptos where codigo='OTRO') c where n=1
on conflict(temporada_id,persona_id,clave_origen) where clave_origen is not null
do update set importe_base=30,descripcion='Torneo TEST',estado='activo',updated_at=now();

insert into public.economia_pagos(id,cargo_id,importe,metodo,fecha_pago,registrado_por)
select private.test_uuid('econ:pago:manual1'),private.test_uuid('econ:manual:1'),30,'efectivo',current_date,p.auth_user_id
from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
where p.auth_user_id is not null limit 1 on conflict(id) do nothing;

-- Overpayment / subsequent price reduction creates a credit for the same person.
insert into public.economia_pagos(id,cargo_id,importe,metodo,fecha_pago,registrado_por)
select private.test_uuid('econ:pago:equip2'),private.test_uuid('econ:equip:2'),35,'efectivo',current_date,p.auth_user_id
from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
where p.auth_user_id is not null limit 1 on conflict(id) do nothing;
insert into public.economia_ajustes(id,cargo_id,tipo,importe,nombre,motivo,origen)
values(private.test_uuid('econ:ajuste:equip2-credit'),private.test_uuid('econ:equip:2'),'regularizacion',-10,'Regularizacion TEST','Cambio aceptado antes de entrega','manual')
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
('TEST-S','economia_ajustes',private.test_uuid('econ:ajuste:equip2-credit')),
('TEST-S','economia_cargos',private.test_uuid('econ:cuota:1')),
('TEST-S','economia_cargos',private.test_uuid('econ:cuota:2')),
('TEST-S','economia_cargos',private.test_uuid('econ:equip:1')),
('TEST-S','economia_cargos',private.test_uuid('econ:equip:2')),
('TEST-S','economia_cargos',private.test_uuid('econ:manual:1'))
on conflict do nothing;

-- Functional assertions.
do $$
declare a record; b record; e1 record; e2 record; m record; p1 uuid; p2 uuid;
begin
 select persona_id into p1 from econ_people where n=1;
 select persona_id into p2 from econ_people where n=2;

 select * into a from public.economia_estado_cargos where cargo_id=private.test_uuid('econ:cuota:1');
 if a.importe_exigible<>275 or a.importe_pagado<>100 or a.saldo_pendiente<>175 or a.estado_pago<>'parcialmente_pagado' then
   raise exception 'ECONOMIA: sibling 1 fee incorrect';
 end if;
 select * into b from public.economia_estado_cargos where cargo_id=private.test_uuid('econ:cuota:2');
 if b.importe_exigible<>200 or b.importe_pagado<>0 or b.saldo_pendiente<>200 or b.estado_pago<>'pendiente' then
   raise exception 'ECONOMIA: sibling 2 fee/discount incorrect';
 end if;
 if (select count(*) from public.economia_cargos where persona_id=p1 and temporada_id=a.temporada_id and clave_origen='CUOTA_TEMPORADA')<>1 then
   raise exception 'ECONOMIA: team change duplicated season fee';
 end if;

 select * into e1 from public.economia_estado_cargos where cargo_id=private.test_uuid('econ:equip:1');
 select * into e2 from public.economia_estado_cargos where cargo_id=private.test_uuid('econ:equip:2');
 if e1.importe_exigible<>190 or e1.importe_pagado<>0 then raise exception 'ECONOMIA: complete equipment incorrect'; end if;
 if e2.importe_exigible<>25 or e2.importe_pagado<>35 or e2.saldo_pendiente<>-10 then raise exception 'ECONOMIA: same-person credit incorrect'; end if;

 select * into m from public.economia_estado_cargos where cargo_id=private.test_uuid('econ:manual:1');
 if m.importe_exigible<>30 or m.importe_pagado<>30 or m.estado_pago<>'pagado' then raise exception 'ECONOMIA: manual charge/payment incorrect'; end if;

 -- Payment on sibling 1 must not appear in sibling 2 account.
 if exists(select 1 from public.economia_pagos pg join public.economia_cargos c on c.id=pg.cargo_id
           where c.persona_id=p2 and pg.id=private.test_uuid('econ:pago:cuota1')) then
   raise exception 'ECONOMIA: cross-sibling payment detected';
 end if;
end $$;

update private.test_datasets set scenario='ECONOMIA',loaded_at=now(),
 metadata='{"purpose":"functional economy scenario","version":"v1"}'::jsonb where id='TEST-S';
commit;
