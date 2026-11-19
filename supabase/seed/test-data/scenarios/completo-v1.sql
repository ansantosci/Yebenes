-- TEST-S COMPLETO v1
-- Final cross-module validation after BASELINE + ECONOMIA + EQUIPACIONES + NOTIFICATIONS.
begin;

do $$
declare
  v_players integer;
  v_coaches integer;
  v_econ integer;
  v_needs integer;
  v_assign integer;
  v_orders integer;
  v_notifications integer;
  v_cross integer;
begin
  select count(*) into v_players
  from public.jugadores j join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id;
  select count(*) into v_coaches
  from public.entrenadores c join private.test_dataset_entities e
    on e.dataset_id='TEST-S' and e.table_name='entrenadores' and e.entity_id=c.id;
  select count(*) into v_econ
  from public.economia_cargos c
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=c.id);
  select count(*) into v_needs
  from public.equipacion_necesidades n
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades' and e.entity_id=n.id);
  select count(*) into v_assign
  from public.equipacion_asignaciones a
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='equipacion_asignaciones' and e.entity_id=a.id);
  select count(*) into v_orders
  from public.equipacion_pedidos p
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='equipacion_pedidos' and e.entity_id=p.id);
  select count(*) into v_notifications
  from public.notificaciones_salida n
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='notificaciones_salida' and e.entity_id=n.id);

  if v_players<1 then raise exception 'COMPLETO: baseline players missing'; end if;
  if v_coaches<1 then raise exception 'COMPLETO: baseline coaches missing'; end if;
  if v_econ<1 then raise exception 'COMPLETO: economy overlay missing'; end if;
  if v_needs<1 or v_assign<1 then raise exception 'COMPLETO: equipment logistics missing (needs %, assignments %)',v_needs,v_assign; end if;
  if v_orders<1 then raise exception 'COMPLETO: equipment orders missing'; end if;
  if v_notifications<1 then raise exception 'COMPLETO: notifications overlay missing'; end if;

  -- Canonical entity integrity: every active player with a current team assignment in the active season
  -- must have the common player participation for that season.
  if exists(
    select 1
    from public.jugadores j
    join public.inscripciones i on i.jugador_id=j.id
    join public.temporadas t on t.id=i.temporada_id and t.estado='activa'
    join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id
      and aje.fecha_desde<=current_date and (aje.fecha_hasta is null or aje.fecha_hasta>=current_date)
    where j.activo
      and not exists(
        select 1 from public.persona_participaciones_temporada ppt
        where ppt.persona_id=j.persona_id and ppt.temporada_id=i.temporada_id and ppt.faceta='jugador'
      )
  ) then raise exception 'COMPLETO: active player/team assignment without canonical player participation'; end if;

  -- Current operational equipment flows must not finish with a negative equipment balance.
  if exists(
    select 1
    from public.economia_estado_cargos ec
    join public.economia_cargos c on c.id=ec.cargo_id
    join public.economia_conceptos co on co.id=c.concepto_id and co.codigo='EQUIPACION'
    where ec.saldo_pendiente<0
  ) then raise exception 'COMPLETO: equipment charge with negative balance/overpayment'; end if;

  -- Cross-module coverage is validated after the deterministic bridge below.
  null;
end $$;


-- Deterministic cross-module bridge for end-to-end UI:
-- the first ECONOMIA player also gets one ordinary equipment need in the same season.
with target as (
  select ec.persona_id,ec.temporada_id,j.id jugador_id
  from public.economia_cargos ec
  join public.jugadores j on j.persona_id=ec.persona_id
  where exists(select 1 from private.test_dataset_entities e
               where e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=ec.id)
  order by ec.persona_id limit 1
), pack as (
  select p.id from public.equipacion_packs p
  join target t on t.temporada_id=p.temporada_id
  order by p.created_at,p.id limit 1
)
insert into public.equipacion_necesidades(
 id,persona_id,temporada_id,faceta,jugador_id,pack_id,estado,origen,comunicada_at)
select private.test_uuid('complete:cross:need'),t.persona_id,t.temporada_id,'jugador',t.jugador_id,p.id,
       'comunicada','manual',now()
from target t cross join pack p
on conflict(id) do update set persona_id=excluded.persona_id,temporada_id=excluded.temporada_id,
 jugador_id=excluded.jugador_id,pack_id=excluded.pack_id,estado='comunicada',updated_at=now();

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
values('TEST-S','equipacion_necesidades',private.test_uuid('complete:cross:need'))
on conflict do nothing;

do $$
begin
 if not exists(
   select 1 from public.economia_cargos ec
   join public.equipacion_necesidades en
     on en.persona_id=ec.persona_id and en.temporada_id=ec.temporada_id
   where exists(select 1 from private.test_dataset_entities e
                where e.dataset_id='TEST-S' and e.table_name='economia_cargos' and e.entity_id=ec.id)
     and exists(select 1 from private.test_dataset_entities e
                where e.dataset_id='TEST-S' and e.table_name='equipacion_necesidades' and e.entity_id=en.id)
 ) then raise exception 'COMPLETO: deterministic economy + equipment cross-module person missing'; end if;
end $$;


-- ============================================================
-- MATRIX v2 - canonical cross-module equipment population
-- Every active player has an equipment lifecycle position.
-- Only confirmed size/choice creates logistics demand and economic obligation.
-- ============================================================

-- Stable active-player matrix: same canonical identities already used by Fichas.
create temporary table test_matrix_players on commit drop as
select j.id jugador_id,j.persona_id,i.temporada_id,e.id equipo_id,e.codigo equipo_codigo,
       row_number() over(order by e.codigo,j.id) rn
from public.jugadores j
join public.inscripciones i on i.jugador_id=j.id
join public.temporadas t on t.id=i.temporada_id and t.estado='activa'
join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id
 and aje.fecha_desde<=current_date and (aje.fecha_hasta is null or aje.fecha_hasta>=current_date)
join public.equipos e on e.id=aje.equipo_id and e.temporada_id=i.temporada_id
where j.activo;

-- Every canonical player gets a season equipment position. Roughly 1/7 remains pending
-- club validation; existing deterministic anchor cases are preserved.
insert into public.equipacion_personas_temporada(
 id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at,observaciones)
select private.test_uuid('matrix2:ept:'||m.jugador_id::text),m.persona_id,m.temporada_id,'jugador',m.jugador_id,
       case when mod(m.rn,7)=1 then 'pendiente_validacion' else 'validada' end,
       case when mod(m.rn,7)=1 then null else now()-interval '14 days' end,
       'TEST-S MATRIX v2'
from test_matrix_players m
on conflict(temporada_id,faceta,jugador_id) do nothing;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_personas_temporada',pt.id
from public.equipacion_personas_temporada pt
join test_matrix_players m on m.jugador_id=pt.jugador_id and m.temporada_id=pt.temporada_id
on conflict do nothing;

-- Validated people receive a size draft. Roughly 1/7 of the whole population remains
-- unconfirmed: valid lifecycle state, but no logistics demand and no equipment charge.
insert into public.equipacion_tallas_persona(
 id,persona_id,temporada_id,talla_general,aplica_todas,confirmada_at)
select private.test_uuid('matrix2:size:'||m.jugador_id::text),m.persona_id,m.temporada_id,
       case mod(m.rn,5) when 0 then 'S' when 1 then 'XS' when 2 then 'M' when 3 then 'XL' else '3XL' end,
       true,
       case when mod(m.rn,7)=2 then null else now()-interval '12 days' end
from test_matrix_players m
join public.equipacion_personas_temporada pt on pt.jugador_id=m.jugador_id and pt.temporada_id=m.temporada_id
where pt.estado='validada'
on conflict(persona_id,temporada_id) do nothing;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_tallas_persona',tp.id
from public.equipacion_tallas_persona tp
join test_matrix_players m on m.persona_id=tp.persona_id and m.temporada_id=tp.temporada_id
on conflict do nothing;

-- Confirmed players without an existing anchor need get one match pack need. Reuse choice
-- alternates deterministically, exercising both 190 EUR and 35 EUR modalities.
insert into public.equipacion_necesidades(
 id,persona_id,temporada_id,faceta,jugador_id,persona_temporada_id,pack_id,tipo_partido,
 reutiliza_entrenamiento,estado,origen,confirmada_at,comunicada_at)
select private.test_uuid('matrix2:need:'||m.jugador_id::text),m.persona_id,m.temporada_id,'jugador',m.jugador_id,pt.id,
       private.test_uuid('equip:pack:partido'),'campo',(mod(m.rn,2)=0),'validada','temporada',
       now()-interval '10 days',now()-interval '10 days'
from test_matrix_players m
join public.equipacion_personas_temporada pt on pt.jugador_id=m.jugador_id and pt.temporada_id=m.temporada_id and pt.estado='validada'
join public.equipacion_tallas_persona tp on tp.persona_id=m.persona_id and tp.temporada_id=m.temporada_id and tp.confirmada_at is not null
where not exists(select 1 from public.equipacion_necesidades n where n.jugador_id=m.jugador_id and n.temporada_id=m.temporada_id and n.estado<>'cancelada')
on conflict(id) do nothing;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_necesidades',n.id
from public.equipacion_necesidades n
join test_matrix_players m on m.jugador_id=n.jugador_id and m.temporada_id=n.temporada_id
where n.id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
on conflict do nothing;

-- Reconcile the economic obligation through the production business function, not by
-- fabricating ledger rows. This preserves person/season ownership and modality rules.
do $$ declare r record; cid uuid; begin
 for r in
   select n.id
   from public.equipacion_necesidades n
   join test_matrix_players m on n.id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
 loop
   cid:=private.equipacion_recalcular_cargo(r.id);
 end loop;
end $$;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','economia_cargos',c.id
from public.economia_cargos c
join test_matrix_players m on c.equipacion_necesidad_id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
on conflict do nothing;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','economia_cargo_equipacion',ce.cargo_id
from public.economia_cargo_equipacion ce
join public.economia_cargos c on c.id=ce.cargo_id
join test_matrix_players m on c.equipacion_necesidad_id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
on conflict do nothing;

-- Stock-backed AVAILABLE cohort (M). A valid lot is created as well so 085 can be exercised.
with s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_stock(id,temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
select private.test_uuid('matrix2:stock:cam:M'),s.temporada_id,private.test_uuid('equip:art:cam-par'),'M',100,0 from s
union all select private.test_uuid('matrix2:stock:pan:M'),s.temporada_id,private.test_uuid('equip:art:pan-par'),'M',100,0 from s
on conflict(temporada_id,articulo_id,talla) do update set cantidad_fisica=greatest(public.equipacion_stock.cantidad_fisica,100);
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values
('TEST-S','equipacion_stock',private.test_uuid('matrix2:stock:cam:M')),
('TEST-S','equipacion_stock',private.test_uuid('matrix2:stock:pan:M')) on conflict do nothing;

insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
select private.test_uuid('matrix2:lot:cam:M'),private.test_uuid('equip:art:cam-par'),'M',t.id,'TEST-S','MATRIX2-M-CAM',100,0 from public.temporadas t where t.estado='activa'
union all select private.test_uuid('matrix2:lot:pan:M'),private.test_uuid('equip:art:pan-par'),'M',t.id,'TEST-S','MATRIX2-M-PAN',100,0 from public.temporadas t where t.estado='activa'
on conflict(id) do nothing;
insert into public.equipacion_stock_lote_vigencia(id,lote_id,temporada_id,estado,decidido_at,observaciones)
select private.test_uuid('matrix2:vig:cam:M'),private.test_uuid('matrix2:lot:cam:M'),t.id,'valido',now(),'MATRIX v2' from public.temporadas t where t.estado='activa'
union all select private.test_uuid('matrix2:vig:pan:M'),private.test_uuid('matrix2:lot:pan:M'),t.id,'valido',now(),'MATRIX v2' from public.temporadas t where t.estado='activa'
on conflict(lote_id,temporada_id) do update set estado='valido',decidido_at=now();
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values
('TEST-S','equipacion_stock_lotes',private.test_uuid('matrix2:lot:cam:M')),
('TEST-S','equipacion_stock_lotes',private.test_uuid('matrix2:lot:pan:M')),
('TEST-S','equipacion_stock_lote_vigencia',private.test_uuid('matrix2:vig:cam:M')),
('TEST-S','equipacion_stock_lote_vigencia',private.test_uuid('matrix2:vig:pan:M')) on conflict do nothing;

-- Formal supplier coverage for XL cohort.
with s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_pedidos(id,temporada_id,numero,proveedor_nombre,proveedor_contacto,fecha_pedido,estado,observaciones)
select private.test_uuid('matrix2:order:XL'),s.temporada_id,'TEST-MATRIX2-XL','Patrick','TEST-S',current_date-2,'pedido','MATRIX v2 supplier cohort' from s
on conflict(id) do update set estado='pedido';
insert into public.equipacion_pedido_lineas(id,pedido_id,articulo_id,talla,cantidad_pedida,precio_unitario) values
(private.test_uuid('matrix2:ol:cam:XL'),private.test_uuid('matrix2:order:XL'),private.test_uuid('equip:art:cam-par'),'XL',100,18),
(private.test_uuid('matrix2:ol:pan:XL'),private.test_uuid('matrix2:order:XL'),private.test_uuid('equip:art:pan-par'),'XL',100,12)
on conflict(pedido_id,articulo_id,talla) where dorsal is null do update set cantidad_pedida=100;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values
('TEST-S','equipacion_pedidos',private.test_uuid('matrix2:order:XL')),
('TEST-S','equipacion_pedido_lineas',private.test_uuid('matrix2:ol:cam:XL')),
('TEST-S','equipacion_pedido_lineas',private.test_uuid('matrix2:ol:pan:XL')) on conflict do nothing;

-- PREPARED cohort (XS): create traceable reservations for both pack garments.
insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
select private.test_uuid('matrix2:lot:cam:XS'),private.test_uuid('equip:art:cam-par'),'XS',t.id,'TEST-S','MATRIX2-XS-CAM',100,0 from public.temporadas t where t.estado='activa'
union all select private.test_uuid('matrix2:lot:pan:XS'),private.test_uuid('equip:art:pan-par'),'XS',t.id,'TEST-S','MATRIX2-XS-PAN',100,0 from public.temporadas t where t.estado='activa'
on conflict(id) do nothing;
insert into public.equipacion_stock_lote_vigencia(id,lote_id,temporada_id,estado,decidido_at,observaciones)
select private.test_uuid('matrix2:vig:cam:XS'),private.test_uuid('matrix2:lot:cam:XS'),t.id,'valido',now(),'MATRIX v2' from public.temporadas t where t.estado='activa'
union all select private.test_uuid('matrix2:vig:pan:XS'),private.test_uuid('matrix2:lot:pan:XS'),t.id,'valido',now(),'MATRIX v2' from public.temporadas t where t.estado='activa'
on conflict(lote_id,temporada_id) do update set estado='valido';

with targets as (
 select m.*,n.id necesidad_id
 from test_matrix_players m join public.equipacion_necesidades n on n.id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
 where mod(m.rn,5)=1
), arts as (
 select private.test_uuid('equip:art:cam-par') articulo_id,'cam' k union all
 select private.test_uuid('equip:art:pan-par'),'pan'
)
insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen,reservado_at)
select private.test_uuid('matrix2:assign:'||t.jugador_id::text||':'||a.k),t.necesidad_id,a.articulo_id,'XS',1,'reservada','automatico',now()-interval '2 days'
from targets t cross join arts a
on conflict(necesidad_id,articulo_id,talla) do update set estado='reservada',reservado_at=excluded.reservado_at;

insert into public.equipacion_asignacion_lotes(id,asignacion_id,lote_id,cantidad,estado,reservado_at)
select private.test_uuid('matrix2:al:'||m.jugador_id::text||':'||x.k),
       private.test_uuid('matrix2:assign:'||m.jugador_id::text||':'||x.k),
       case when x.k='cam' then private.test_uuid('matrix2:lot:cam:XS') else private.test_uuid('matrix2:lot:pan:XS') end,
       1,'reservada',now()-interval '2 days'
from test_matrix_players m cross join (values('cam'),('pan')) x(k)
where mod(m.rn,5)=1 and exists(select 1 from public.equipacion_necesidades n where n.id=private.test_uuid('matrix2:need:'||m.jugador_id::text))
on conflict(asignacion_id,lote_id) do update set estado='reservada';

-- DELIVERED cohort (S): complete both garments and retain delivery history.
with targets as (
 select m.*,n.id necesidad_id
 from test_matrix_players m join public.equipacion_necesidades n on n.id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
 where mod(m.rn,5)=0
), arts as (
 select private.test_uuid('equip:art:cam-par') articulo_id,'cam' k union all
 select private.test_uuid('equip:art:pan-par'),'pan'
)
insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen,reservado_at)
select private.test_uuid('matrix2:assign:'||t.jugador_id::text||':'||a.k),t.necesidad_id,a.articulo_id,'S',1,'entregada','automatico',now()-interval '5 days'
from targets t cross join arts a
on conflict(necesidad_id,articulo_id,talla) do update set estado='entregada';
insert into public.equipacion_entregas(id,asignacion_id,cantidad,entregada_at,observaciones)
select private.test_uuid('matrix2:delivery:'||m.jugador_id::text||':'||x.k),
       private.test_uuid('matrix2:assign:'||m.jugador_id::text||':'||x.k),1,now()-interval '4 days','MATRIX v2 delivered cohort'
from test_matrix_players m cross join (values('cam'),('pan')) x(k)
where mod(m.rn,5)=0 and exists(select 1 from public.equipacion_necesidades n where n.id=private.test_uuid('matrix2:need:'||m.jugador_id::text))
on conflict(asignacion_id) do nothing;

-- Register generated logistics so RESET remains deterministic.
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_asignaciones',a.id from public.equipacion_asignaciones a
join test_matrix_players m on a.necesidad_id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
on conflict do nothing;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_asignacion_lotes',al.id from public.equipacion_asignacion_lotes al
join public.equipacion_asignaciones a on a.id=al.asignacion_id
join test_matrix_players m on a.necesidad_id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
on conflict do nothing;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_entregas',d.id from public.equipacion_entregas d
join public.equipacion_asignaciones a on a.id=d.asignacion_id
join test_matrix_players m on a.necesidad_id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
on conflict do nothing;

-- Assertions: population integrity and meaningful lifecycle coverage.
do $$ declare total integer; positioned integer; confirmed integer; pending integer; prepared integer; delivered integer; begin
 select count(*) into total from test_matrix_players;
 select count(*) into positioned from test_matrix_players m where exists(
   select 1 from public.equipacion_personas_temporada pt where pt.jugador_id=m.jugador_id and pt.temporada_id=m.temporada_id);
 select count(distinct n.jugador_id) into confirmed from public.equipacion_necesidades n
   join test_matrix_players m on m.jugador_id=n.jugador_id and m.temporada_id=n.temporada_id
   where n.confirmada_at is not null and n.estado<>'cancelada';
 select count(distinct persona_id) into pending from public.equipacion_estado_operativo where estado_operativo='pendiente_compra';
 select count(distinct persona_id) into prepared from public.equipacion_estado_operativo where estado_operativo='preparada';
 select count(distinct persona_id) into delivered from public.equipacion_estado_operativo where estado_operativo='entregada';
 if total<>167 then raise exception 'MATRIX v2: expected 167 canonical active players after retiring historical E067C, got %',total; end if;
 if positioned<>total then raise exception 'MATRIX v2: every canonical player must have an equipment lifecycle position (%/%).',positioned,total; end if;
 if confirmed<80 then raise exception 'MATRIX v2: insufficient confirmed equipment population: %',confirmed; end if;
 if pending<10 or prepared<10 or delivered<10 then raise exception 'MATRIX v2: insufficient logistics diversity pending %, prepared %, delivered %',pending,prepared,delivered; end if;
 -- Matrix v2 owns only matrix2:need:* rows. Legacy anchor needs remain audited separately.
 if exists(
   select 1
   from public.equipacion_necesidades n
   join test_matrix_players m
     on n.id=private.test_uuid('matrix2:need:'||m.jugador_id::text)
   where n.confirmada_at is not null
     and n.estado<>'cancelada'
     and not exists(
       select 1 from public.economia_cargos c
       where c.equipacion_necesidad_id=n.id and c.estado='activo'
     )
 )
 then raise exception 'MATRIX v2: matrix-owned confirmed equipment need without active economic obligation'; end if;
end $$;

update private.test_datasets
set scenario='COMPLETO',loaded_at=now(),
    metadata=jsonb_build_object(
      'purpose','integrated transversal club simulation',
      'version','v2',
      'overlays',jsonb_build_array('BASELINE','ECONOMIA','EQUIPACIONES','NOTIFICATIONS')
    )
where id='TEST-S';

commit;
