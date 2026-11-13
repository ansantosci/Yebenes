-- TEST-S EQUIPACIONES v1: synthetic operational coverage for DEVELOP/TEST.
begin;

update private.test_datasets set scenario='EQUIPACIONES',version='1.3',metadata='{"purpose":"equipaciones operational coverage","base":"TEST-S BASELINE"}'::jsonb,loaded_at=now() where id='TEST-S';

-- Season configuration.
insert into public.equipacion_config_temporada(id,temporada_id,proveedor_nombre,proveedor_contacto,precio_pack_completo,precio_solo_partido,politica_tecnicos,campana_estado,campana_abre_at,campana_limite,campana_mensaje)
select private.test_uuid('equip:config'),t.id,'Patrick','TEST-S proveedor',190,35,'seleccion_manual','abierta',now(),date '2027-01-31','TEST-S Equipaciones'
from public.temporadas t where t.estado='activa' limit 1
on conflict(temporada_id) do update set proveedor_nombre='Patrick',precio_pack_completo=190,precio_solo_partido=35,campana_estado='abierta',campana_mensaje='TEST-S Equipaciones';
insert into private.test_dataset_entities select 'TEST-S','equipacion_config_temporada',private.test_uuid('equip:config'),now() on conflict do nothing;

-- Articles.
insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo) values
(private.test_uuid('equip:art:cam-ent'),'Camiseta entrenamiento','TEST-EQ-CAM-ENT','camiseta','jugador','general',true,true),
(private.test_uuid('equip:art:pan-ent'),'Pantalón entrenamiento','TEST-EQ-PAN-ENT','pantalon','jugador','general',true,true),
(private.test_uuid('equip:art:cam-par'),'Camiseta partido campo','TEST-EQ-CAM-PAR','camiseta','jugador','campo',true,true),
(private.test_uuid('equip:art:pan-par'),'Pantalón partido','TEST-EQ-PAN-PAR','pantalon','jugador','campo',true,true),
(private.test_uuid('equip:art:tecnico'),'Polo técnico','TEST-EQ-TEC','polo','entrenador','general',true,true)
on conflict(codigo) do update set nombre=excluded.nombre,activo=true;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_articulos',id from public.equipacion_articulos where codigo like 'TEST-EQ-%' on conflict do nothing;

-- Packs.
with s as (select id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_packs(id,temporada_id,codigo,nombre,destinatario,modalidad,precio,activo)
select private.test_uuid('equip:pack:full'),id,'TEST-PACK-ENTRENAMIENTO','Pack entrenamiento','jugador','entrenamiento',190,true from s
union all select private.test_uuid('equip:pack:partido'),id,'TEST-PACK-PARTIDO','Solo jugar 35 €','jugador','partido_campo',35,true from s
union all select private.test_uuid('equip:pack:tecnico'),id,'TEST-PACK-TECNICO','Equipación técnico','entrenador','tecnico',0,true from s
on conflict(temporada_id,codigo) do update set nombre=excluded.nombre,precio=excluded.precio,activo=true;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values
('TEST-S','equipacion_packs',private.test_uuid('equip:pack:full')),('TEST-S','equipacion_packs',private.test_uuid('equip:pack:partido')),('TEST-S','equipacion_packs',private.test_uuid('equip:pack:tecnico')) on conflict do nothing;

-- Pack composition.
insert into public.equipacion_pack_articulos(id,pack_id,articulo_id,cantidad,obligatorio,orden) values
(private.test_uuid('equip:pa:1'),private.test_uuid('equip:pack:full'),private.test_uuid('equip:art:cam-ent'),1,true,10),
(private.test_uuid('equip:pa:2'),private.test_uuid('equip:pack:full'),private.test_uuid('equip:art:pan-ent'),1,true,20),
(private.test_uuid('equip:pa:5'),private.test_uuid('equip:pack:partido'),private.test_uuid('equip:art:cam-par'),1,true,10),
(private.test_uuid('equip:pa:6'),private.test_uuid('equip:pack:partido'),private.test_uuid('equip:art:pan-par'),1,true,20),
(private.test_uuid('equip:pa:7'),private.test_uuid('equip:pack:tecnico'),private.test_uuid('equip:art:tecnico'),1,true,10)
on conflict(pack_id,articulo_id) do update set cantidad=excluded.cantidad,obligatorio=true;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_pack_articulos',x from (values (private.test_uuid('equip:pa:1')),(private.test_uuid('equip:pa:2')),(private.test_uuid('equip:pa:5')),(private.test_uuid('equip:pa:6')),(private.test_uuid('equip:pa:7'))) v(x) on conflict do nothing;

-- Six players from BASELINE: varied general sizes and one per-garment exception.
with p as (
 select j.id jugador_id,j.persona_id,row_number() over(order by e.codigo,j.id) n
 from public.jugadores j
 join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id
 join public.inscripciones i on i.jugador_id=j.id
 join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id and aje.fecha_hasta is null
 join public.equipos e on e.id=aje.equipo_id
 join public.temporadas t on t.id=i.temporada_id and t.estado='activa'
 limit 6
), s as (select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_tallas_persona(id,persona_id,temporada_id,talla_general,aplica_todas,confirmada_at)
select private.test_uuid('equip:size:'||p.jugador_id::text),p.persona_id,s.temporada_id,(array['3XS','2XS','XS','S','M','L'])[p.n],p.n<>2,now() from p cross join s
on conflict(persona_id,temporada_id) do update set talla_general=excluded.talla_general,aplica_todas=excluded.aplica_todas,confirmada_at=now();
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_tallas_persona',tp.id
from public.jugadores j
join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id
join public.equipacion_tallas_persona tp on tp.persona_id=j.persona_id
join public.temporadas t on t.id=tp.temporada_id and t.estado='activa'
order by j.id limit 6 on conflict do nothing;

with tp as (
  select t.id talla_persona_id,
         row_number() over(order by t.persona_id,t.id) n
  from public.equipacion_tallas_persona t
  join private.test_dataset_entities de
    on de.dataset_id='TEST-S'
   and de.table_name='equipacion_tallas_persona'
   and de.entity_id=t.id
  join public.temporadas s
    on s.id=t.temporada_id
   and s.estado='activa'
)
insert into public.equipacion_tallas_excepcion(id,talla_persona_id,articulo_id,talla)
select private.test_uuid('equip:exception'),
       tp.talla_persona_id,
       private.test_uuid('equip:art:cam-par'),
       'S'
from tp
where tp.n=2
on conflict(talla_persona_id,articulo_id) do update set talla='S';

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_tallas_excepcion',te.id
from public.equipacion_tallas_excepcion te
where te.id=private.test_uuid('equip:exception')
on conflict do nothing;

-- Needs: 4 full pack, 2 reuse training / match-only. Different workflow states.
with p as (
 select j.id jugador_id,j.persona_id,row_number() over(order by j.id) n
 from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id order by j.id limit 6
), s as (select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,pack_id,tipo_partido,reutiliza_entrenamiento,estado,origen,comunicada_at)
select private.test_uuid('equip:need:'||p.jugador_id::text),p.persona_id,s.temporada_id,'jugador',p.jugador_id,
 case when p.n<=4 then private.test_uuid('equip:pack:full') else private.test_uuid('equip:pack:partido') end,
 'campo',p.n>4,(array['comunicada','validada','preparacion','completa','validada','comunicada'])[p.n],'temporada',now()
from p cross join s
on conflict(id) do update set pack_id=excluded.pack_id,reutiliza_entrenamiento=excluded.reutiliza_entrenamiento,estado=excluded.estado,comunicada_at=now();
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_necesidades',private.test_uuid('equip:need:'||j.id::text) from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id order by j.id limit 6 on conflict do nothing;

-- 062 multipack coverage: first four players also need a separate match pack.
with p as (
 select j.id jugador_id,j.persona_id,row_number() over(order by j.id) n
 from public.jugadores j join private.test_dataset_entities de
   on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id
 order by j.id limit 4
), s as (select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,pack_id,tipo_partido,reutiliza_entrenamiento,estado,origen,comunicada_at)
select private.test_uuid('equip:need:match:'||p.jugador_id::text),p.persona_id,s.temporada_id,'jugador',p.jugador_id,
       private.test_uuid('equip:pack:partido'),'campo',false,'validada','temporada',now()
from p cross join s
on conflict(id) do update set pack_id=excluded.pack_id,estado=excluded.estado,comunicada_at=now();

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_necesidades',private.test_uuid('equip:need:match:'||j.id::text)
from public.jugadores j join private.test_dataset_entities de
 on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id
order by j.id limit 4 on conflict do nothing;

-- One coach need, to cover trainer sizing.
with c as (select e.id entrenador_id,e.persona_id from public.entrenadores e join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='entrenadores' and de.entity_id=e.id order by e.id limit 1), s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_tallas_persona(id,persona_id,temporada_id,talla_general,aplica_todas,confirmada_at)
select private.test_uuid('equip:size:coach'),c.persona_id,s.temporada_id,'L',true,now() from c cross join s on conflict(persona_id,temporada_id) do update set talla_general='L',confirmada_at=now();
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_tallas_persona',tp.id
from public.entrenadores e
join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='entrenadores' and de.entity_id=e.id
join public.equipacion_tallas_persona tp on tp.persona_id=e.persona_id
join public.temporadas t on t.id=tp.temporada_id and t.estado='activa'
order by e.id limit 1 on conflict do nothing;
with c as (select e.id entrenador_id,e.persona_id from public.entrenadores e join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='entrenadores' and de.entity_id=e.id order by e.id limit 1), s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,entrenador_id,pack_id,reutiliza_tecnico,estado,origen,comunicada_at)
select private.test_uuid('equip:need:coach'),c.persona_id,s.temporada_id,'entrenador',c.entrenador_id,private.test_uuid('equip:pack:tecnico'),false,'validada','temporada',now() from c cross join s
on conflict(id) do update set pack_id=excluded.pack_id,estado='validada';
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_necesidades',private.test_uuid('equip:need:coach')) on conflict do nothing;

-- Stock with shortages to exercise purchase suggestions.
with s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_stock(id,temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
select private.test_uuid('equip:stock:1'),s.temporada_id,private.test_uuid('equip:art:cam-ent'),'3XS',2,0 from s union all
select private.test_uuid('equip:stock:2'),s.temporada_id,private.test_uuid('equip:art:pan-ent'),'3XS',1,0 from s union all
select private.test_uuid('equip:stock:3'),s.temporada_id,private.test_uuid('equip:art:cam-par'),'S',1,0 from s union all
select private.test_uuid('equip:stock:4'),s.temporada_id,private.test_uuid('equip:art:pan-par'),'S',0,0 from s
on conflict(temporada_id,articulo_id,talla) do update set cantidad_fisica=excluded.cantidad_fisica,cantidad_reservada=excluded.cantidad_reservada;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) select 'TEST-S','equipacion_stock',private.test_uuid('equip:stock:'||g) from generate_series(1,4) g on conflict do nothing;

-- Two simultaneous supplier orders.
with s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_pedidos(id,temporada_id,numero,proveedor_nombre,proveedor_contacto,fecha_pedido,estado,observaciones)
select private.test_uuid('equip:order:1'),s.temporada_id,'TEST-P-001','Patrick','TEST-S',current_date-10,'parcialmente_recibido','Pedido sintético parcialmente recibido' from s union all
select private.test_uuid('equip:order:2'),s.temporada_id,'TEST-P-002','Patrick','TEST-S',current_date-3,'pedido','Segundo pedido simultáneo' from s
on conflict(id) do update set estado=excluded.estado,observaciones=excluded.observaciones;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_pedidos',private.test_uuid('equip:order:1')),('TEST-S','equipacion_pedidos',private.test_uuid('equip:order:2')) on conflict do nothing;

insert into public.equipacion_pedido_lineas(id,pedido_id,articulo_id,talla,cantidad_pedida,precio_unitario) values
(private.test_uuid('equip:ol:1'),private.test_uuid('equip:order:1'),private.test_uuid('equip:art:cam-par'),'S',5,18),
(private.test_uuid('equip:ol:2'),private.test_uuid('equip:order:1'),private.test_uuid('equip:art:pan-par'),'S',5,12),
(private.test_uuid('equip:ol:3'),private.test_uuid('equip:order:2'),private.test_uuid('equip:art:cam-ent'),'XS',4,15),
(private.test_uuid('equip:ol:4'),private.test_uuid('equip:order:2'),private.test_uuid('equip:art:pan-ent'),'XS',4,10)
on conflict(pedido_id,articulo_id,talla) where dorsal is null do update set cantidad_pedida=excluded.cantidad_pedida,precio_unitario=excluded.precio_unitario;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) select 'TEST-S','equipacion_pedido_lineas',private.test_uuid('equip:ol:'||g) from generate_series(1,4) g on conflict do nothing;

insert into public.equipacion_recepciones(id,pedido_id,fecha_recepcion,referencia,observaciones)
values(private.test_uuid('equip:recv:1'),private.test_uuid('equip:order:1'),current_date-2,'TEST-R-001','Recepción parcial sintética')
on conflict(id) do update set observaciones=excluded.observaciones;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_recepciones',private.test_uuid('equip:recv:1')) on conflict do nothing;
insert into public.equipacion_recepcion_lineas(id,recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada,observaciones) values
(private.test_uuid('equip:rl:1'),private.test_uuid('equip:recv:1'),private.test_uuid('equip:ol:1'),3,3,'Aceptadas'),
(private.test_uuid('equip:rl:2'),private.test_uuid('equip:recv:1'),private.test_uuid('equip:ol:2'),2,2,'Aceptadas')
on conflict(recepcion_id,pedido_linea_id) do update set cantidad_recibida=excluded.cantidad_recibida,cantidad_aceptada=excluded.cantidad_aceptada;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_recepcion_lineas',private.test_uuid('equip:rl:1')),('TEST-S','equipacion_recepcion_lineas',private.test_uuid('equip:rl:2')) on conflict do nothing;

-- Dorsals for six players, including goalkeeper conventions 1 and 13.
with p as (
 select j.id jugador_id,aje.equipo_id,row_number() over(order by j.id) n
 from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id
 join public.inscripciones i on i.jugador_id=j.id
 join public.asignaciones_jugador_equipo aje on aje.inscripcion_id=i.id and aje.fecha_hasta is null
 order by j.id limit 6
), s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_dorsales(id,temporada_id,equipo_id,jugador_id,dorsal,es_portero,origen)
select private.test_uuid('equip:number:'||p.jugador_id::text),s.temporada_id,p.equipo_id,p.jugador_id,(array[1,13,7,9,10,25])[p.n],p.n in (1,2,6),'manual' from p cross join s
on conflict(temporada_id,equipo_id,jugador_id) do update set dorsal=excluded.dorsal,es_portero=excluded.es_portero;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_dorsales',private.test_uuid('equip:number:'||j.id::text) from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id order by j.id limit 6 on conflict do nothing;

-- One prepared assignment and one delivered item.
with p as (select j.id from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id order by j.id limit 1)
insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen,reservado_at)
select private.test_uuid('equip:assign:1'),private.test_uuid('equip:need:'||id::text),private.test_uuid('equip:art:cam-ent'),'3XS',1,'entregada','manual',now() from p
on conflict(necesidad_id,articulo_id,talla) do update set estado='entregada';
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_asignaciones',private.test_uuid('equip:assign:1')) on conflict do nothing;
insert into public.equipacion_entregas(id,asignacion_id,cantidad,entregada_at,observaciones)
values(private.test_uuid('equip:delivery:1'),private.test_uuid('equip:assign:1'),1,now()-interval '1 day','Entrega sintética')
on conflict(asignacion_id) do update set cantidad=1,observaciones='Entrega sintética';
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_entregas',private.test_uuid('equip:delivery:1')) on conflict do nothing;


-- Scenario preflight: validate all key synthetic relationships before commit.
-- Rich cases for the refined Equipaciones model (056-058).
with p as (
 select j.id jugador_id,j.persona_id,row_number() over(order by j.id) n
 from public.jugadores j join private.test_dataset_entities de
 on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id
 order by j.id limit 6
), t as (select id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
select private.test_uuid('equip:season-person:'||p.n),p.persona_id,t.id,'jugador',p.jugador_id,
 case when p.n=6 then 'pendiente_validacion' else 'validada' end,
 case when p.n=6 then null else now()-interval '10 days' end
from p,t
on conflict(temporada_id,faceta,jugador_id) do update set estado=excluded.estado,validada_at=excluded.validada_at;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_personas_temporada',id from public.equipacion_personas_temporada
where id in (select private.test_uuid('equip:season-person:'||g) from generate_series(1,6) g)
on conflict do nothing;

-- Confirm sizes only for club-validated people. This is deliberately before
-- persona_temporada_id/confirmada_at is attached to needs, because 056 enforces that order.
with validated as (
  select pt.persona_id,pt.temporada_id,row_number() over(order by pt.persona_id) n
  from public.equipacion_personas_temporada pt
  where pt.id in (select private.test_uuid('equip:season-person:'||g) from generate_series(1,5) g)
    and pt.estado='validada'
)
insert into public.equipacion_tallas_persona(id,temporada_id,persona_id,talla_general,confirmada_at)
select private.test_uuid('equip:confirmed-size:'||n),temporada_id,persona_id,
       case when n=1 then '3XS' when n=2 then '2XS' when n=3 then 'XS' when n=4 then 'S' else 'M' end,
       now()-interval '8 days'
from validated
on conflict(temporada_id,persona_id) do update
set talla_general=excluded.talla_general,confirmada_at=excluded.confirmada_at;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_tallas_persona',id
from public.equipacion_tallas_persona
where id in (select private.test_uuid('equip:confirmed-size:'||g) from generate_series(1,5) g)
on conflict do nothing;

update public.equipacion_necesidades n
set persona_temporada_id=pt.id,confirmada_at=coalesce(n.confirmada_at,now()-interval '7 days')
from public.equipacion_personas_temporada pt
where pt.persona_id=n.persona_id and pt.temporada_id=n.temporada_id and pt.estado='validada'
and n.id in (select entity_id from private.test_dataset_entities where dataset_id='TEST-S' and table_name='equipacion_necesidades');

-- Three traceable stock lots: current, historical reusable, historical rejected.
-- Fail close if the synthetic article master changed unexpectedly.
do $$
begin
  if not exists(select 1 from public.equipacion_articulos where codigo='TEST-EQ-CAM-ENT') then
    raise exception 'EQUIPACIONES fixture: TEST-EQ-CAM-ENT article missing';
  end if;
  if not exists(select 1 from public.equipacion_articulos where codigo='TEST-EQ-CAM-PAR') then
    raise exception 'EQUIPACIONES fixture: TEST-EQ-CAM-PAR article missing';
  end if;
end $$;

with t as (select id from public.temporadas where estado='activa' limit 1),
a as (select id from public.equipacion_articulos where codigo='TEST-EQ-CAM-ENT' limit 1)
insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
select private.test_uuid('equip:lot:current'),a.id,'3XS',t.id,'Patrick','CURRENT-3XS',5,1 from t,a
on conflict(id) do update set cantidad_fisica=5,cantidad_reservada=1;

with t as (select id from public.temporadas where estado='activa' limit 1),
a as (select id from public.equipacion_articulos where codigo='TEST-EQ-CAM-ENT' limit 1)
insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
select private.test_uuid('equip:lot:historic-valid'),a.id,'3XS',t.id,'Patrick','PREV-VALID',3,0 from t,a
on conflict(id) do update set cantidad_fisica=3,cantidad_reservada=0;

with t as (select id from public.temporadas where estado='activa' limit 1),
a as (select id from public.equipacion_articulos where codigo='TEST-EQ-CAM-PAR' limit 1)
insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
select private.test_uuid('equip:lot:historic-invalid'),a.id,'3XS',t.id,'Proveedor anterior','OLD-KIT',2,0 from t,a
on conflict(id) do update set cantidad_fisica=2,cantidad_reservada=0;

do $$
declare n integer;
begin
  select count(*) into n from public.equipacion_stock_lotes
  where id in (
    private.test_uuid('equip:lot:current'),
    private.test_uuid('equip:lot:historic-valid'),
    private.test_uuid('equip:lot:historic-invalid')
  );
  if n<>3 then
    raise exception 'EQUIPACIONES fixture: expected 3 traceable stock lots, found %',n;
  end if;
end $$;

with t as (select id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_stock_lote_vigencia(id,lote_id,temporada_id,estado,decidido_at,observaciones)
values
(private.test_uuid('equip:lot-validity:current'),private.test_uuid('equip:lot:current'),(select id from t),'valido',now(),'Stock actual'),
(private.test_uuid('equip:lot-validity:historic-valid'),private.test_uuid('equip:lot:historic-valid'),(select id from t),'valido',now(),'Stock anterior reutilizable'),
(private.test_uuid('equip:lot-validity:historic-invalid'),private.test_uuid('equip:lot:historic-invalid'),(select id from t),'no_valido',now(),'Equipación anterior incompatible')
on conflict(lote_id,temporada_id) do update set estado=excluded.estado,decidido_at=excluded.decidido_at,observaciones=excluded.observaciones;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_stock_lotes',x from (values
(private.test_uuid('equip:lot:current')),(private.test_uuid('equip:lot:historic-valid')),(private.test_uuid('equip:lot:historic-invalid'))) v(x)
on conflict do nothing;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_stock_lote_vigencia',x from (values
(private.test_uuid('equip:lot-validity:current')),(private.test_uuid('equip:lot-validity:historic-valid')),(private.test_uuid('equip:lot-validity:historic-invalid'))) v(x)
on conflict do nothing;


-- Functional state matrix for UI validation.
-- Person 5: club validated, sizing still pending => no logistical need should be created.
update public.equipacion_personas_temporada
set estado='validada',validada_at=coalesce(validada_at,now()-interval '2 days')
where id=private.test_uuid('equip:season-person:5');

delete from public.equipacion_necesidades
where persona_id=(select persona_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:5'))
  and temporada_id=(select temporada_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:5'));

delete from public.equipacion_tallas_persona
where persona_id=(select persona_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:5'))
  and temporada_id=(select temporada_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:5'));

-- Person 6 remains pending club validation and therefore has neither confirmed sizes nor need.
delete from public.equipacion_necesidades
where persona_id=(select persona_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:6'))
  and temporada_id=(select temporada_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:6'));
delete from public.equipacion_tallas_persona
where persona_id=(select persona_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:6'))
  and temporada_id=(select temporada_id from public.equipacion_personas_temporada where id=private.test_uuid('equip:season-person:6'));

-- Mark one confirmed player as reusing training equipment; match shirt remains required.
update public.equipacion_necesidades
set reutiliza_entrenamiento=true,tipo_partido='campo'
where persona_temporada_id=private.test_uuid('equip:season-person:2');

-- Preserve an explicit per-garment size exception for a confirmed player.
with target as (
 select persona_id,temporada_id from public.equipacion_personas_temporada
 where id=private.test_uuid('equip:season-person:3')
), art as (
 select id from public.equipacion_articulos where codigo='TEST-EQ-PAN-ENT'
)
insert into public.equipacion_tallas_excepcion(id,talla_persona_id,articulo_id,talla)
select private.test_uuid('equip:size-exception:matrix'),
       tp.id,art.id,'2XS'
from target t
join public.equipacion_tallas_persona tp on tp.persona_id=t.persona_id and tp.temporada_id=t.temporada_id
cross join art
on conflict(talla_persona_id,articulo_id) do update set talla=excluded.talla;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
values('TEST-S','equipacion_tallas_excepcion',private.test_uuid('equip:size-exception:matrix'))
on conflict do nothing;

-- Assertions for the lifecycle matrix.
do $$
declare
  pending_sizes integer;
  pending_validation integer;
  bad_needs integer;
begin
 select count(*) into pending_sizes
 from public.equipacion_personas_temporada pt
 where pt.id=private.test_uuid('equip:season-person:5') and pt.estado='validada'
   and not exists(select 1 from public.equipacion_tallas_persona tp
                  where tp.persona_id=pt.persona_id and tp.temporada_id=pt.temporada_id and tp.confirmada_at is not null);
 if pending_sizes<>1 then raise exception 'EQUIPACIONES fixture: validated/pending-size case missing'; end if;

 select count(*) into pending_validation
 from public.equipacion_personas_temporada
 where id=private.test_uuid('equip:season-person:6') and estado='pendiente_validacion';
 if pending_validation<>1 then raise exception 'EQUIPACIONES fixture: pending-validation case missing'; end if;

 select count(*) into bad_needs
 from public.equipacion_necesidades n
 where n.persona_id in (
   select persona_id from public.equipacion_personas_temporada
   where id in (private.test_uuid('equip:season-person:5'),private.test_uuid('equip:season-person:6'))
 );
 if bad_needs<>0 then raise exception 'EQUIPACIONES fixture: pending lifecycle cases must not create needs'; end if;
end $$;


-- Multipack delivery state for confirmed player 4:
-- training is delivered 2/2 through traceable lots; the separate match need remains pending.
do $$
declare
  train_need uuid;
  match_need uuid;
  tid uuid;
  personid uuid;
  talla text;
  cam_asg uuid:=private.test_uuid('equip:assign:partial:cam-ent');
  pan_asg uuid:=private.test_uuid('equip:assign:partial:pan-ent');
  cam_lot uuid:=private.test_uuid('equip:lot:player4:cam-ent');
  pan_lot uuid:=private.test_uuid('equip:lot:player4:pan-ent');
  test_auth_uid uuid;
  r record;
begin
  select n.persona_id,n.temporada_id,tp.talla_general
    into personid,tid,talla
  from public.equipacion_necesidades n
  join public.equipacion_personas_temporada pt on pt.id=n.persona_temporada_id
  join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
  where pt.id=private.test_uuid('equip:season-person:4')
  limit 1;

  select n.id into train_need
  from public.equipacion_necesidades n
  where n.persona_id=personid and n.temporada_id=tid
    and n.pack_id=private.test_uuid('equip:pack:full');

  select n.id into match_need
  from public.equipacion_necesidades n
  where n.persona_id=personid and n.temporada_id=tid
    and n.pack_id=private.test_uuid('equip:pack:partido');

  if train_need is null or match_need is null then
    raise exception 'EQUIPACIONES fixture: player 4 multipack needs missing';
  end if;

  insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
  values
    (cam_asg,train_need,private.test_uuid('equip:art:cam-ent'),talla,1,'propuesta','manual'),
    (pan_asg,train_need,private.test_uuid('equip:art:pan-ent'),talla,1,'propuesta','manual')
  on conflict(id) do update set necesidad_id=excluded.necesidad_id,articulo_id=excluded.articulo_id,
    talla=excluded.talla,cantidad=1,estado='propuesta',reservado_at=null,updated_at=now();

  insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
  values
    (cam_lot,private.test_uuid('equip:art:cam-ent'),talla,tid,'Patrick','PLAYER4-CAM',1,0),
    (pan_lot,private.test_uuid('equip:art:pan-ent'),talla,tid,'Patrick','PLAYER4-PAN',1,0)
  on conflict(id) do update set cantidad_fisica=1,cantidad_reservada=0,updated_at=now();

  insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,observaciones)
  values
    (cam_lot,tid,'valido',now(),'TEST-S player 4'),
    (pan_lot,tid,'valido',now(),'TEST-S player 4')
  on conflict(lote_id,temporada_id) do update set estado='valido',decidido_at=now();

  select p.auth_user_id into test_auth_uid
  from public.personas p
  join public.persona_roles pr on pr.persona_id=p.id and pr.activo
    and pr.fecha_desde<=current_date and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
  join public.roles ro on ro.id=pr.rol_id and ro.codigo in ('administrador','club')
  where p.activo and p.auth_user_id is not null
  order by (ro.codigo='administrador') desc limit 1;
  if test_auth_uid is null then raise exception 'EQUIPACIONES fixture: no admin/club identity for logistics RPC'; end if;
  perform set_config('request.jwt.claim.sub',test_auth_uid::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);

  perform private.equipacion_reservar_asignacion_lote(cam_asg,cam_lot,1);
  perform private.equipacion_reservar_asignacion_lote(pan_asg,pan_lot,1);
  perform private.equipacion_confirmar_entrega(cam_asg,test_auth_uid);
  perform private.equipacion_confirmar_entrega(pan_asg,test_auth_uid);

  select * into r from public.equipacion_reparto_resumen where necesidad_id=train_need;
  if r.estado_reparto is distinct from 'completo' or r.prendas_asignadas<>2 or r.prendas_entregadas<>2 then
    raise exception 'EQUIPACIONES fixture: expected training delivered 2/2, got %/% state %',
      coalesce(r.prendas_entregadas,0),coalesce(r.prendas_asignadas,0),coalesce(r.estado_reparto,'NULL');
  end if;

  select * into r from public.equipacion_reparto_resumen where necesidad_id=match_need;
  if r.estado_reparto is distinct from 'pendiente' or r.prendas_entregadas<>0 then
    raise exception 'EQUIPACIONES fixture: expected separate match pack pending, state %',
      coalesce(r.estado_reparto,'NULL');
  end if;

  if (select count(*) from public.equipacion_material_persona
      where persona_id=personid and temporada_id=tid and pack_id=private.test_uuid('equip:pack:full'))<>2 then
    raise exception 'EQUIPACIONES fixture: expected two delivered training garments in personal inventory';
  end if;
end $$;



-- Stable reparto matrix for V96 frontend/end-to-end validation.
-- Uses confirmed existing needs and creates deterministic assignments/lots without replacing legacy cases.
do $$
declare
 tid uuid; test_auth_uid uuid;
 rec record; needid uuid; talla text; aid uuid; lotid uuid; asgid uuid;
begin
 select id into tid from public.temporadas where estado='activa' limit 1;
 select p.auth_user_id into test_auth_uid
 from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
 join public.roles ro on ro.id=pr.rol_id and ro.codigo in ('administrador','club')
 where p.auth_user_id is not null order by (ro.codigo='administrador') desc limit 1;
 if test_auth_uid is null then raise exception 'EQUIPACIONES reparto matrix: no club/admin identity'; end if;
 perform set_config('request.jwt.claim.sub',test_auth_uid::text,true);
 perform set_config('request.jwt.claim.role','authenticated',true);

 -- Player 1 match pack: AVAILABLE DIRECTLY (two garments, free stock).
 select n.id,tp.talla_general into needid,talla
 from public.equipacion_necesidades n
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where n.id=(select private.test_uuid('equip:need:match:'||j.id::text)
             from public.jugadores j join private.test_dataset_entities e on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id order by j.id limit 1);
 if needid is not null then
   foreach aid in array array[private.test_uuid('equip:art:cam-par'),private.test_uuid('equip:art:pan-par')] loop
     asgid:=private.test_uuid('matrix:available:asg:'||aid::text);
     lotid:=private.test_uuid('matrix:available:lot:'||aid::text);
     insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
     values(asgid,needid,aid,talla,1,'propuesta','manual')
     on conflict(id) do update set necesidad_id=excluded.necesidad_id,articulo_id=excluded.articulo_id,talla=excluded.talla,estado='propuesta',reservado_at=null;
     insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
     values(lotid,aid,talla,tid,'Patrick','MATRIX-AVAILABLE',1,0)
     on conflict(id) do update set cantidad_fisica=1,cantidad_reservada=0,updated_at=now();
     insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,observaciones)
     values(lotid,tid,'valido',now(),'V96 disponible directo')
     on conflict(lote_id,temporada_id) do update set estado='valido',decidido_at=now();
   end loop;
 end if;

 -- Player 2 match pack: PREPARED (one reserved garment; second remains available).
 select n.id,tp.talla_general into needid,talla
 from public.equipacion_necesidades n
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where n.id=(select private.test_uuid('equip:need:match:'||j.id::text)
             from public.jugadores j join private.test_dataset_entities e on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id order by j.id offset 1 limit 1);
 if needid is not null then
   aid:=private.test_uuid('equip:art:cam-par'); asgid:=private.test_uuid('matrix:prepared:asg'); lotid:=private.test_uuid('matrix:prepared:lot');
   insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
   values(asgid,needid,aid,talla,1,'propuesta','manual') on conflict(id) do update set talla=excluded.talla,estado='propuesta',reservado_at=null;
   insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
   values(lotid,aid,talla,tid,'Patrick','MATRIX-PREPARED',1,0) on conflict(id) do update set cantidad_fisica=1,cantidad_reservada=0,updated_at=now();
   insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at) values(lotid,tid,'valido',now())
   on conflict(lote_id,temporada_id) do update set estado='valido',decidido_at=now();
   perform private.equipacion_reservar_asignacion_lote(asgid,lotid,1);
 end if;

 -- Player 3 match pack: PENDING SUPPLIER through the existing open order, no free stock.
 select n.id,tp.talla_general into needid,talla
 from public.equipacion_necesidades n
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where n.id=(select private.test_uuid('equip:need:match:'||j.id::text)
             from public.jugadores j join private.test_dataset_entities e on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id order by j.id offset 2 limit 1);
 if needid is not null then
   aid:=private.test_uuid('equip:art:cam-par'); asgid:=private.test_uuid('matrix:supplier:asg');
   insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
   values(asgid,needid,aid,'S',1,'propuesta','manual') on conflict(id) do update set talla='S',estado='propuesta',reservado_at=null;
 end if;

 -- Player 4 already supplies the COMPLETED training pack + pending separate match pack.
end $$;

-- Register matrix entities for reset traceability.
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_asignaciones',x from (values
 (private.test_uuid('matrix:available:asg:'||private.test_uuid('equip:art:cam-par')::text)),
 (private.test_uuid('matrix:available:asg:'||private.test_uuid('equip:art:pan-par')::text)),
 (private.test_uuid('matrix:prepared:asg')),
 (private.test_uuid('matrix:supplier:asg'))
) v(x)
where exists(select 1 from public.equipacion_asignaciones a where a.id=x)
on conflict do nothing;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_stock_lotes',x from (values
 (private.test_uuid('matrix:available:lot:'||private.test_uuid('equip:art:cam-par')::text)),
 (private.test_uuid('matrix:available:lot:'||private.test_uuid('equip:art:pan-par')::text)),
 (private.test_uuid('matrix:prepared:lot'))
) v(x)
where exists(select 1 from public.equipacion_stock_lotes l where l.id=x)
on conflict do nothing;

-- Matrix assertions: at least one delivered, prepared, available and supplier-covered assignment.
do $$
begin
 if not exists(select 1 from public.equipacion_estado_operativo where temporada_id=(select id from public.temporadas where estado='activa' limit 1) and estado_operativo='entregada')
 then raise exception 'EQUIPACIONES reparto matrix: delivered case missing'; end if;
 if not exists(select 1 from public.equipacion_estado_operativo where temporada_id=(select id from public.temporadas where estado='activa' limit 1) and estado_operativo='preparada')
 then raise exception 'EQUIPACIONES reparto matrix: prepared case missing'; end if;
 if not exists(select 1 from public.equipacion_estado_operativo where temporada_id=(select id from public.temporadas where estado='activa' limit 1) and estado_operativo='disponible')
 then raise exception 'EQUIPACIONES reparto matrix: available case missing'; end if;
 if not exists(select 1 from public.equipacion_estado_operativo where temporada_id=(select id from public.temporadas where estado='activa' limit 1) and estado_operativo='pedido_proveedor')
 then raise exception 'EQUIPACIONES reparto matrix: supplier case missing'; end if;
end $$;


-- Reparto matrix v2: explicit partial, soft-displacement and debt-labelled cases.
-- Partial: player 1 match pack gets one garment delivered and one still pending.
do $$
declare
 needid uuid; v_talla text; asg uuid; lot uuid; actor uuid;
begin
 select n.id,tp.talla_general into needid,v_talla
 from public.equipacion_necesidades n
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where n.id=(select private.test_uuid('equip:need:match:'||j.id::text)
             from public.jugadores j join private.test_dataset_entities e
             on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id
             order by j.id limit 1);
 select p.auth_user_id into actor from public.personas p
 join public.persona_roles pr on pr.persona_id=p.id and pr.activo
 join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
 where p.auth_user_id is not null order by (r.codigo='administrador') desc limit 1;
 if needid is not null and actor is not null then
   perform set_config('request.jwt.claim.sub',actor::text,true);
   perform set_config('request.jwt.claim.role','authenticated',true);
   select id into asg from public.equipacion_asignaciones
   where necesidad_id=needid and articulo_id=private.test_uuid('equip:art:cam-par') and public.equipacion_asignaciones.talla=v_talla
   order by created_at,id limit 1;
   if asg is null then raise exception 'EQUIPACIONES reparto matrix v2: reusable assignment for partial case missing'; end if;
   update public.equipacion_asignaciones set estado='propuesta',reservado_at=null,updated_at=now() where id=asg;
   lot:=private.test_uuid('matrix:partial:lot');
   insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
   values(lot,private.test_uuid('equip:art:cam-par'),v_talla,(select id from public.temporadas where estado='activa' limit 1),'Patrick','MATRIX-PARTIAL',1,0)
   on conflict(id) do update set cantidad_fisica=1,cantidad_reservada=0,updated_at=now();
   insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at)
   values(lot,(select id from public.temporadas where estado='activa' limit 1),'valido',now())
   on conflict(lote_id,temporada_id) do update set estado='valido',decidido_at=now();
   perform private.equipacion_reservar_asignacion_lote(asg,lot,1);
   perform private.equipacion_confirmar_entrega(asg,actor);
 end if;
end $$;

-- Soft-displacement: one prepared assignment consumes the only physical unit;
-- another assignment of same article/size therefore has physical-but-committed coverage.
do $$
declare tid uuid; need_a uuid; need_b uuid; v_talla text; lot uuid; asg_a uuid; asg_b uuid; actor uuid;
begin
 select id into tid from public.temporadas where estado='activa' limit 1;
 select p.auth_user_id into actor from public.personas p join public.persona_roles pr on pr.persona_id=p.id and pr.activo
 join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
 where p.auth_user_id is not null order by (r.codigo='administrador') desc limit 1;
 select n.id,tp.talla_general into need_a,v_talla from public.equipacion_necesidades n
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where n.id=(select private.test_uuid('equip:need:match:'||j.id::text) from public.jugadores j
 join private.test_dataset_entities e on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id order by j.id offset 1 limit 1);
 select n.id into need_b from public.equipacion_necesidades n
 where n.id=(select private.test_uuid('equip:need:match:'||j.id::text) from public.jugadores j
 join private.test_dataset_entities e on e.dataset_id='TEST-S' and e.table_name='jugadores' and e.entity_id=j.id order by j.id offset 3 limit 1);
 if need_a is not null and need_b is not null then
   select id into asg_a from public.equipacion_asignaciones
    where necesidad_id=need_a and articulo_id=private.test_uuid('equip:art:pan-par') and public.equipacion_asignaciones.talla=v_talla
    order by created_at,id limit 1;
   if asg_a is null then
     asg_a:=private.test_uuid('matrix:soft:prepared');
     insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
     values(asg_a,need_a,private.test_uuid('equip:art:pan-par'),v_talla,1,'propuesta','manual');
   else update public.equipacion_asignaciones set estado='propuesta',reservado_at=null,updated_at=now() where id=asg_a; end if;
   select id into asg_b from public.equipacion_asignaciones
    where necesidad_id=need_b and articulo_id=private.test_uuid('equip:art:pan-par') and public.equipacion_asignaciones.talla=v_talla
    order by created_at,id limit 1;
   if asg_b is null then
     asg_b:=private.test_uuid('matrix:soft:beneficiary');
     insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
     values(asg_b,need_b,private.test_uuid('equip:art:pan-par'),v_talla,1,'propuesta','manual');
   else update public.equipacion_asignaciones set estado='propuesta',reservado_at=null,updated_at=now() where id=asg_b; end if;
   lot:=private.test_uuid('matrix:soft:lot');
   insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
   values(lot,private.test_uuid('equip:art:pan-par'),v_talla,tid,'Patrick','MATRIX-SOFT',1,0)
   on conflict(id) do update set cantidad_fisica=1,cantidad_reservada=0,updated_at=now();
   insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at)
   values(lot,tid,'valido',now()) on conflict(lote_id,temporada_id) do update set estado='valido',decidido_at=now();
   perform set_config('request.jwt.claim.sub',actor::text,true); perform set_config('request.jwt.claim.role','authenticated',true);
   perform private.equipacion_reservar_asignacion_lote(asg_a,lot,1);
 end if;
end $$;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_asignaciones',x from (values
 (private.test_uuid('matrix:partial:asg')),(private.test_uuid('matrix:soft:prepared')),(private.test_uuid('matrix:soft:beneficiary'))
) v(x) where exists(select 1 from public.equipacion_asignaciones a where a.id=x) on conflict do nothing;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_stock_lotes',x from (values
 (private.test_uuid('matrix:partial:lot')),(private.test_uuid('matrix:soft:lot'))
) v(x) where exists(select 1 from public.equipacion_stock_lotes l where l.id=x) on conflict do nothing;

do $$
declare tid uuid;
begin
 select id into tid from public.temporadas where estado='activa' limit 1;
 if not exists(select 1 from public.equipacion_reparto_resumen where temporada_id=tid and estado_reparto='parcial')
 then raise exception 'EQUIPACIONES reparto matrix v2: partial case missing'; end if;
 if not exists(
   select 1 from public.equipacion_asignaciones a
   join public.equipacion_necesidades n on n.id=a.necesidad_id
   where a.estado='propuesta'
     and exists(select 1 from public.equipacion_stock_lotes l join public.equipacion_stock_lote_vigencia v on v.lote_id=l.id
       where v.temporada_id=n.temporada_id and v.estado='valido' and l.articulo_id=a.articulo_id and l.talla=a.talla
         and l.cantidad_fisica>0 and l.cantidad_fisica=l.cantidad_reservada)
 ) then raise exception 'EQUIPACIONES reparto matrix v2: soft displacement case missing'; end if;
 if not exists(select 1 from public.equipacion_estado_operativo where temporada_id=tid and coalesce(saldo_pendiente,0)>0)
 then raise exception 'EQUIPACIONES reparto matrix v2: equipment debt case missing'; end if;
end $$;



do $$
declare
  v_missing integer;
begin
  select count(*) into v_missing
  from private.test_dataset_entities de
  where de.dataset_id='TEST-S'
    and de.table_name in (
      'equipacion_config_temporada','equipacion_articulos','equipacion_packs','equipacion_pack_articulos',
      'equipacion_tallas_persona','equipacion_tallas_excepcion','equipacion_necesidades','equipacion_stock',
      'equipacion_pedidos','equipacion_pedido_lineas','equipacion_recepciones','equipacion_recepcion_lineas',
      'equipacion_dorsales','equipacion_asignaciones','equipacion_entregas'
    )
    and de.entity_id is null;
  if v_missing > 0 then raise exception 'EQUIPACIONES fixture: % null registered entity ids',v_missing; end if;

  if not exists (select 1 from public.equipacion_tallas_excepcion where id=private.test_uuid('equip:exception')) then
    raise exception 'EQUIPACIONES fixture: size exception missing';
  end if;
  if (select count(*) from public.equipacion_pedidos where id in (private.test_uuid('equip:order:1'),private.test_uuid('equip:order:2'))) <> 2 then
    raise exception 'EQUIPACIONES fixture: expected two simultaneous orders';
  end if;
  if (select count(*) from public.equipacion_recepcion_lineas where recepcion_id=private.test_uuid('equip:recv:1')) <> 2 then
    raise exception 'EQUIPACIONES fixture: expected two partial reception lines';
  end if;
  if (select count(*) from public.equipacion_dorsales where id in (
      select entity_id from private.test_dataset_entities where dataset_id='TEST-S' and table_name='equipacion_dorsales'
    )) < 1 then
    raise exception 'EQUIPACIONES fixture: dorsals missing';
  end if;
end $$;

commit;
