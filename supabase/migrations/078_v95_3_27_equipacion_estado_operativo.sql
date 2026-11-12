-- 078 - Read-only operational equipment status by person/need/item.
-- No business operation or persisted workflow state is introduced here.
begin;

create or replace view public.equipacion_estado_operativo as
with accepted as (
  select rl.pedido_linea_id,sum(rl.cantidad_aceptada)::integer aceptada
  from public.equipacion_recepcion_lineas rl
  group by rl.pedido_linea_id
), proveedor as (
  select pe.temporada_id,pl.articulo_id,pl.talla,
         sum(greatest(pl.cantidad_pedida-coalesce(ac.aceptada,0),0))::integer pendiente_proveedor
  from public.equipacion_pedidos pe
  join public.equipacion_pedido_lineas pl on pl.pedido_id=pe.id
  left join accepted ac on ac.pedido_linea_id=pl.id
  where pe.estado in ('pedido','parcialmente_recibido')
  group by pe.temporada_id,pl.articulo_id,pl.talla
), reservas as (
  select al.asignacion_id,
         coalesce(sum(al.cantidad) filter(where al.estado='reservada'),0)::integer cantidad_reservada_asignacion
  from public.equipacion_asignacion_lotes al
  group by al.asignacion_id
), cargo as (
  select distinct on(c.equipacion_necesidad_id)
         c.equipacion_necesidad_id necesidad_id,e.cargo_id,e.importe_exigible,e.importe_pagado,
         greatest(e.saldo_pendiente,0)::numeric(10,2) saldo_pendiente,e.estado_pago
  from public.economia_cargos c
  join public.economia_estado_cargos e on e.cargo_id=c.id
  where c.origen='equipacion' and c.estado='activo' and c.equipacion_necesidad_id is not null
  order by c.equipacion_necesidad_id,c.created_at desc,c.id
)
select
 d.temporada_id,d.persona_id,n.faceta,n.jugador_id,n.entrenador_id,
 n.id necesidad_id,n.pack_id,p.nombre pack_nombre,
 (n.pack_id is null and n.articulo_id_adicional is not null) necesidad_adicional,
 d.articulo_id,a.nombre articulo_nombre,d.talla,d.cantidad_demandada cantidad_necesaria,
 asi.id asignacion_id,coalesce(asi.estado,'propuesta') estado_asignacion,
 coalesce(r.cantidad_reservada_asignacion,0)::integer cantidad_reservada,
 case when asi.estado='entregada' then asi.cantidad else 0 end::integer cantidad_entregada,
 greatest(coalesce(s.cantidad_fisica,0)-coalesce(s.cantidad_reservada,0),0)::integer stock_disponible,
 coalesce(pr.pendiente_proveedor,0)::integer pendiente_proveedor,
 case
   when asi.estado='entregada' then 'entregada'
   when asi.estado='reservada' and coalesce(r.cantidad_reservada_asignacion,0)>=d.cantidad_demandada then 'preparada'
   when greatest(coalesce(s.cantidad_fisica,0)-coalesce(s.cantidad_reservada,0),0)>=d.cantidad_demandada then 'disponible'
   when greatest(coalesce(s.cantidad_fisica,0)-coalesce(s.cantidad_reservada,0),0)+coalesce(pr.pendiente_proveedor,0)>=d.cantidad_demandada then 'pedido_proveedor'
   else 'pendiente_compra'
 end estado_operativo,
 c.cargo_id,c.importe_exigible,c.importe_pagado,c.saldo_pendiente,c.estado_pago,
 n.sin_cargo,n.precio_unitario_snapshot
from public.equipacion_demanda_logistica d
join public.equipacion_necesidades n on n.id=d.necesidad_id
join public.equipacion_articulos a on a.id=d.articulo_id
left join public.equipacion_packs p on p.id=n.pack_id
left join public.equipacion_asignaciones asi
  on asi.necesidad_id=d.necesidad_id and asi.articulo_id=d.articulo_id and asi.talla=d.talla and asi.estado<>'cancelada'
left join reservas r on r.asignacion_id=asi.id
left join public.equipacion_stock s
  on s.temporada_id=d.temporada_id and s.articulo_id=d.articulo_id and s.talla=d.talla
left join proveedor pr
  on pr.temporada_id=d.temporada_id and pr.articulo_id=d.articulo_id and pr.talla=d.talla
left join cargo c on c.necesidad_id=d.necesidad_id;

comment on view public.equipacion_estado_operativo is
'078 read-only operational projection. preparada=reserved for this assignment; disponible=free stock fully covers item; pedido_proveedor=free stock plus formally ordered pending receipt fully covers item; pendiente_compra=coverage remains incomplete.';

grant select on public.equipacion_estado_operativo to authenticated,service_role;
revoke all on public.equipacion_estado_operativo from anon;

commit;
