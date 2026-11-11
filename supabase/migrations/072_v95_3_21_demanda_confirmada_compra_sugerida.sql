-- 072 - Confirmed demand is the sole source for supplier purchase suggestions.
-- No individual stock reservation is created by family confirmation.
begin;

create or replace view public.equipacion_demanda_logistica as
select
  n.temporada_id,
  n.id as necesidad_id,
  n.persona_id,
  n.faceta,
  pa.articulo_id,
  case
    when not a.usa_talla then 'SIN_TALLA'
    else coalesce(ex.talla,tp.talla_general)
  end as talla,
  pa.cantidad as cantidad_demandada
from public.equipacion_necesidades n
join public.equipacion_packs p on p.id=n.pack_id and p.temporada_id=n.temporada_id
join public.equipacion_pack_articulos pa on pa.pack_id=p.id and pa.obligatorio
join public.equipacion_articulos a on a.id=pa.articulo_id and a.activo
join public.equipacion_tallas_persona tp
  on tp.persona_id=n.persona_id and tp.temporada_id=n.temporada_id
 and tp.confirmada_at is not null
left join public.equipacion_tallas_excepcion ex
  on ex.talla_persona_id=tp.id and ex.articulo_id=pa.articulo_id
where n.confirmada_at is not null
  and n.estado in ('comunicada','validada','preparacion','completa')
  and n.pack_id is not null
  and (not a.usa_talla or coalesce(ex.talla,tp.talla_general) is not null);

create or replace view public.equipacion_compra_sugerida as
with d as (
  select temporada_id,articulo_id,talla,sum(cantidad_demandada)::integer demanda_confirmada
  from public.equipacion_demanda_logistica
  group by 1,2,3
), e as (
  select n.temporada_id,a.articulo_id,a.talla,sum(en.cantidad)::integer entregado
  from public.equipacion_entregas en
  join public.equipacion_asignaciones a on a.id=en.asignacion_id
  join public.equipacion_necesidades n on n.id=a.necesidad_id
  group by 1,2,3
), accepted as (
  select rl.pedido_linea_id,sum(rl.cantidad_aceptada)::integer aceptada
  from public.equipacion_recepcion_lineas rl
  group by rl.pedido_linea_id
), p as (
  select pe.temporada_id,pl.articulo_id,pl.talla,
         sum(greatest(pl.cantidad_pedida-coalesce(ac.aceptada,0),0))::integer pendiente_proveedor
  from public.equipacion_pedidos pe
  join public.equipacion_pedido_lineas pl on pl.pedido_id=pe.id
  left join accepted ac on ac.pedido_linea_id=pl.id
  where pe.estado in ('pedido','parcialmente_recibido')
  group by 1,2,3
)
select
 d.temporada_id,d.articulo_id,d.talla,
 d.demanda_confirmada,
 coalesce(e.entregado,0)::integer entregado,
 greatest(d.demanda_confirmada-coalesce(e.entregado,0),0)::integer demanda_pendiente_entrega,
 coalesce(s.cantidad_fisica,0)::integer stock_fisico,
 coalesce(s.cantidad_reservada,0)::integer stock_reservado,
 greatest(coalesce(s.cantidad_fisica,0)-coalesce(s.cantidad_reservada,0),0)::integer stock_disponible,
 coalesce(p.pendiente_proveedor,0)::integer pendiente_proveedor,
 greatest(
   d.demanda_confirmada
   -coalesce(e.entregado,0)
   -coalesce(s.cantidad_fisica,0)
   -coalesce(p.pendiente_proveedor,0),
   0
 )::integer falta_comprar
from d
left join e using(temporada_id,articulo_id,talla)
left join public.equipacion_stock s using(temporada_id,articulo_id,talla)
left join p using(temporada_id,articulo_id,talla);

comment on view public.equipacion_demanda_logistica is
'072: demand comes only from confirmed equipment requests/sizes; confirmation does not reserve stock to an individual.';
comment on view public.equipacion_compra_sugerida is
'072: suggested purchase = confirmed demand - delivered - physical stock - ordered supplier quantity still pending receipt. Draft orders do not count.';

grant select on public.equipacion_demanda_logistica,public.equipacion_compra_sugerida to authenticated,service_role;
revoke all on public.equipacion_demanda_logistica,public.equipacion_compra_sugerida from anon;

commit;
