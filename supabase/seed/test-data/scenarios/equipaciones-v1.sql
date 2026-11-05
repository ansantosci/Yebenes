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
select private.test_uuid('equip:pack:full'),id,'TEST-PACK-COMPLETO','Pack completo 190 €','jugador','entrenamiento',190,true from s
union all select private.test_uuid('equip:pack:partido'),id,'TEST-PACK-PARTIDO','Solo jugar 35 €','jugador','partido_campo',35,true from s
union all select private.test_uuid('equip:pack:tecnico'),id,'TEST-PACK-TECNICO','Equipación técnico','entrenador','tecnico',0,true from s
on conflict(temporada_id,codigo) do update set nombre=excluded.nombre,precio=excluded.precio,activo=true;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values
('TEST-S','equipacion_packs',private.test_uuid('equip:pack:full')),('TEST-S','equipacion_packs',private.test_uuid('equip:pack:partido')),('TEST-S','equipacion_packs',private.test_uuid('equip:pack:tecnico')) on conflict do nothing;

-- Pack composition.
insert into public.equipacion_pack_articulos(id,pack_id,articulo_id,cantidad,obligatorio,orden) values
(private.test_uuid('equip:pa:1'),private.test_uuid('equip:pack:full'),private.test_uuid('equip:art:cam-ent'),1,true,10),
(private.test_uuid('equip:pa:2'),private.test_uuid('equip:pack:full'),private.test_uuid('equip:art:pan-ent'),1,true,20),
(private.test_uuid('equip:pa:3'),private.test_uuid('equip:pack:full'),private.test_uuid('equip:art:cam-par'),1,true,30),
(private.test_uuid('equip:pa:4'),private.test_uuid('equip:pack:full'),private.test_uuid('equip:art:pan-par'),1,true,40),
(private.test_uuid('equip:pa:5'),private.test_uuid('equip:pack:partido'),private.test_uuid('equip:art:cam-par'),1,true,10),
(private.test_uuid('equip:pa:6'),private.test_uuid('equip:pack:partido'),private.test_uuid('equip:art:pan-par'),1,true,20),
(private.test_uuid('equip:pa:7'),private.test_uuid('equip:pack:tecnico'),private.test_uuid('equip:art:tecnico'),1,true,10)
on conflict(pack_id,articulo_id) do update set cantidad=excluded.cantidad,obligatorio=true;
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_pack_articulos',private.test_uuid('equip:pa:'||g) from generate_series(1,7) g on conflict do nothing;

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
select 'TEST-S','equipacion_tallas_persona',private.test_uuid('equip:size:'||j.id::text) from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id order by j.id limit 6 on conflict do nothing;

with p as (select j.id,j.persona_id,row_number() over(order by j.id) n from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id order by j.id limit 6)
do $$
begin
  if not exists (
    select 1 from public.equipacion_tallas_persona
    where persona_id='equipacion_tallas_excepcion'::uuid and temporada_id='equip:exception'::uuid
  ) then
    raise exception 'EQUIPACIONES fixture: talla_persona parent missing';
  end if;
end $$;

insert into public.equipacion_tallas_excepcion(id,talla_persona_id,articulo_id,talla)
select private.test_uuid('equip:exception'),
  (select tp.id from public.equipacion_tallas_persona tp
    where tp.persona_id='equipacion_tallas_excepcion'::uuid and tp.temporada_id='equip:exception'::uuid
    limit 1),
  private.test_uuid('equip:art:cam-par'),
  'S' from p where n=2
on conflict(talla_persona_id,articulo_id) do update set talla='S';
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_tallas_excepcion',private.test_uuid('equip:exception')) on conflict do nothing;

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
on conflict(temporada_id,faceta,jugador_id) do update set pack_id=excluded.pack_id,reutiliza_entrenamiento=excluded.reutiliza_entrenamiento,estado=excluded.estado,comunicada_at=now();
insert into private.test_dataset_entities(dataset_id,table_name,entity_id)
select 'TEST-S','equipacion_necesidades',private.test_uuid('equip:need:'||j.id::text) from public.jugadores j join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='jugadores' and de.entity_id=j.id order by j.id limit 6 on conflict do nothing;

-- One coach need, to cover trainer sizing.
with c as (select e.id entrenador_id,e.persona_id from public.entrenadores e join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='entrenadores' and de.entity_id=e.id order by e.id limit 1), s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_tallas_persona(id,persona_id,temporada_id,talla_general,aplica_todas,confirmada_at)
select private.test_uuid('equip:size:coach'),c.persona_id,s.temporada_id,'L',true,now() from c cross join s on conflict(persona_id,temporada_id) do update set talla_general='L',confirmada_at=now();
insert into private.test_dataset_entities(dataset_id,table_name,entity_id) values('TEST-S','equipacion_tallas_persona',private.test_uuid('equip:size:coach')) on conflict do nothing;
with c as (select e.id entrenador_id,e.persona_id from public.entrenadores e join private.test_dataset_entities de on de.dataset_id='TEST-S' and de.table_name='entrenadores' and de.entity_id=e.id order by e.id limit 1), s as(select id temporada_id from public.temporadas where estado='activa' limit 1)
insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,entrenador_id,pack_id,reutiliza_tecnico,estado,origen,comunicada_at)
select private.test_uuid('equip:need:coach'),c.persona_id,s.temporada_id,'entrenador',c.entrenador_id,private.test_uuid('equip:pack:tecnico'),false,'validada','temporada',now() from c cross join s
on conflict(temporada_id,faceta,entrenador_id) do update set pack_id=excluded.pack_id,estado='validada';
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

commit;
