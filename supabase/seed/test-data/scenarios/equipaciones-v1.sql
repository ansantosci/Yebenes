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
on conflict(pedido_id,articulo_id,talla) do update set cantidad_pedida=excluded.cantidad_pedida,precio_unitario=excluded.precio_unitario;
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


-- Partial pack delivery: confirmed player 4 has 3 garment assignments, 2 delivered,
-- while the match shirt remains pending because its size has no available stock.
with target as (
 select n.id necesidad_id,n.persona_id,n.temporada_id,tp.talla_general
 from public.equipacion_necesidades n
 join public.equipacion_personas_temporada pt on pt.id=n.persona_temporada_id
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where pt.id=private.test_uuid('equip:season-person:4')
), vals as (
 select private.test_uuid('equip:assign:partial:cam-ent') id,necesidad_id,private.test_uuid('equip:art:cam-ent') articulo_id,talla_general talla,'entregada' estado from target
 union all
 select private.test_uuid('equip:assign:partial:pan-ent'),necesidad_id,private.test_uuid('equip:art:pan-ent'),talla_general,'entregada' from target
 union all
 select private.test_uuid('equip:assign:partial:cam-par'),necesidad_id,private.test_uuid('equip:art:cam-par'),talla_general,'propuesta' from target
)
insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen,reservado_at)
select id,necesidad_id,articulo_id,talla,1,estado,'manual',
       case when estado='entregada' then now()-interval '1 day' else null end
from vals
on conflict(necesidad_id,articulo_id,talla) do update
set estado=excluded.estado,cantidad=1,reservado_at=excluded.reservado_at;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
values
('TEST-S','equipacion_asignaciones',private.test_uuid('equip:assign:partial:cam-ent')),
('TEST-S','equipacion_asignaciones',private.test_uuid('equip:assign:partial:pan-ent')),
('TEST-S','equipacion_asignaciones',private.test_uuid('equip:assign:partial:cam-par'))
on conflict do nothing;

insert into public.equipacion_entregas(id,asignacion_id,cantidad,entregada_at,observaciones)
values
(private.test_uuid('equip:delivery:partial:cam-ent'),private.test_uuid('equip:assign:partial:cam-ent'),1,now()-interval '1 day','Pack parcial - camiseta entrenamiento'),
(private.test_uuid('equip:delivery:partial:pan-ent'),private.test_uuid('equip:assign:partial:pan-ent'),1,now()-interval '1 day','Pack parcial - pantalón entrenamiento')
on conflict(asignacion_id) do update set cantidad=1,entregada_at=excluded.entregada_at,observaciones=excluded.observaciones;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
values
('TEST-S','equipacion_entregas',private.test_uuid('equip:delivery:partial:cam-ent')),
('TEST-S','equipacion_entregas',private.test_uuid('equip:delivery:partial:pan-ent'))
on conflict do nothing;

-- Current stock after those deliveries: delivered garments are no longer physically available;
-- the pending match shirt also has zero stock in this player's size.
with target as (
 select n.temporada_id,tp.talla_general talla
 from public.equipacion_necesidades n
 join public.equipacion_personas_temporada pt on pt.id=n.persona_temporada_id
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where pt.id=private.test_uuid('equip:season-person:4')
), arts as (
 select private.test_uuid('equip:art:cam-ent') articulo_id from target
 union all select private.test_uuid('equip:art:pan-ent') from target
 union all select private.test_uuid('equip:art:cam-par') from target
)
insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
select t.temporada_id,a.articulo_id,t.talla,0,0 from target t cross join arts a
on conflict(temporada_id,articulo_id,talla) do update set cantidad_fisica=0,cantidad_reservada=0,updated_at=now();

-- Explicit negative movements for the two delivered garments.
with target as (
 select n.temporada_id,tp.talla_general talla
 from public.equipacion_necesidades n
 join public.equipacion_personas_temporada pt on pt.id=n.persona_temporada_id
 join public.equipacion_tallas_persona tp on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 where pt.id=private.test_uuid('equip:season-person:4')
)
insert into public.equipacion_movimientos_stock(id,temporada_id,articulo_id,talla,tipo,cantidad,asignacion_id,referencia,observaciones)
select private.test_uuid('equip:movement:partial:cam-ent'),temporada_id,private.test_uuid('equip:art:cam-ent'),talla,'entrega',-1,private.test_uuid('equip:assign:partial:cam-ent'),'TEST-PARTIAL','Entrega parcial pack' from target
union all
select private.test_uuid('equip:movement:partial:pan-ent'),temporada_id,private.test_uuid('equip:art:pan-ent'),talla,'entrega',-1,private.test_uuid('equip:assign:partial:pan-ent'),'TEST-PARTIAL','Entrega parcial pack' from target
on conflict(id) do update
set temporada_id=excluded.temporada_id,
    articulo_id=excluded.articulo_id,
    talla=excluded.talla,
    tipo=excluded.tipo,
    cantidad=excluded.cantidad,
    asignacion_id=excluded.asignacion_id,
    referencia=excluded.referencia,
    observaciones=excluded.observaciones;

insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
values
('TEST-S','equipacion_movimientos_stock',private.test_uuid('equip:movement:partial:cam-ent')),
('TEST-S','equipacion_movimientos_stock',private.test_uuid('equip:movement:partial:pan-ent'))
on conflict do nothing;

do $$
declare r record;
begin
 select * into r from public.equipacion_reparto_resumen
 where necesidad_id=(select n.id from public.equipacion_necesidades n
   join public.equipacion_personas_temporada pt on pt.id=n.persona_temporada_id
   where pt.id=private.test_uuid('equip:season-person:4'));
 if r.estado_reparto is distinct from 'entrega_parcial' or r.prendas_asignadas<>3 or r.prendas_entregadas<>2 then
   raise exception 'EQUIPACIONES fixture: expected partial delivery 2/3, got %/% state %',
     coalesce(r.prendas_entregadas,0),coalesce(r.prendas_asignadas,0),coalesce(r.estado_reparto,'NULL');
 end if;
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
