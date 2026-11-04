-- V95.3.2 backend logistics - Equipaciones reception/stock closure.
begin;

create table if not exists public.equipacion_movimientos_stock (
  id uuid primary key default gen_random_uuid(),
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  articulo_id uuid not null references public.equipacion_articulos(id) on delete restrict,
  talla text not null default 'SIN_TALLA' check (talla in ('SIN_TALLA','4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL')),
  tipo text not null check (tipo in ('recepcion','entrega','ajuste_positivo','ajuste_negativo','traspaso_entrada','traspaso_salida')),
  cantidad integer not null check (cantidad <> 0),
  recepcion_linea_id uuid references public.equipacion_recepcion_lineas(id) on delete restrict,
  asignacion_id uuid references public.equipacion_asignaciones(id) on delete restrict,
  referencia text,
  observaciones text,
  creado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (recepcion_linea_id),
  check (
    (tipo='recepcion' and cantidad > 0 and recepcion_linea_id is not null)
    or (tipo='entrega' and cantidad < 0 and asignacion_id is not null)
    or tipo in ('ajuste_positivo','ajuste_negativo','traspaso_entrada','traspaso_salida')
  )
);

create or replace function private.equipacion_recalcular_estado_pedido(p_pedido uuid)
returns void language plpgsql security definer set search_path=public,private as $$
declare v_estado text; v_pedida integer; v_aceptada integer;
begin
  select estado into v_estado from public.equipacion_pedidos where id=p_pedido for update;
  if v_estado is null then raise exception 'Order not found'; end if;
  if v_estado in ('cerrado','cancelado','borrador') then return; end if;

  select coalesce(sum(pl.cantidad_pedida),0),
         coalesce(sum((select coalesce(sum(rl.cantidad_aceptada),0)
                       from public.equipacion_recepcion_lineas rl
                       where rl.pedido_linea_id=pl.id)),0)
    into v_pedida,v_aceptada
  from public.equipacion_pedido_lineas pl where pl.pedido_id=p_pedido;

  update public.equipacion_pedidos
     set estado=case when v_aceptada=0 then 'pedido'
                     when v_aceptada < v_pedida then 'parcialmente_recibido'
                     else 'recibido' end,
         updated_at=now()
   where id=p_pedido;
end $$;

create or replace function private.equipacion_aplicar_recepcion_linea()
returns trigger language plpgsql security definer set search_path=public,private as $$
declare
  v_pedido_recepcion uuid; v_pedido_linea uuid; v_temporada uuid; v_articulo uuid; v_talla text;
  v_pedida integer; v_aceptada_previa integer;
begin
  select pedido_id into v_pedido_recepcion from public.equipacion_recepciones where id=new.recepcion_id;
  select pl.pedido_id,pe.temporada_id,pl.articulo_id,pl.talla,pl.cantidad_pedida
    into v_pedido_linea,v_temporada,v_articulo,v_talla,v_pedida
  from public.equipacion_pedido_lineas pl join public.equipacion_pedidos pe on pe.id=pl.pedido_id
  where pl.id=new.pedido_linea_id;

  if v_pedido_recepcion is null or v_pedido_linea is null or v_pedido_recepcion<>v_pedido_linea then
    raise exception 'Reception line must belong to the same order as its reception';
  end if;
  if not exists(select 1 from public.equipacion_pedidos where id=v_pedido_linea and estado in ('pedido','parcialmente_recibido')) then
    raise exception 'Reception can only be registered for an ordered or partially received order';
  end if;

  select coalesce(sum(cantidad_aceptada),0) into v_aceptada_previa
  from public.equipacion_recepcion_lineas where pedido_linea_id=new.pedido_linea_id;
  if v_aceptada_previa + new.cantidad_aceptada > v_pedida then
    raise exception 'Accepted quantity would exceed ordered quantity';
  end if;

  if new.cantidad_aceptada > 0 then
    insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
    values(v_temporada,v_articulo,v_talla,new.cantidad_aceptada,0)
    on conflict(temporada_id,articulo_id,talla) do update
      set cantidad_fisica=public.equipacion_stock.cantidad_fisica+excluded.cantidad_fisica,updated_at=now();

    insert into public.equipacion_movimientos_stock(
      temporada_id,articulo_id,talla,tipo,cantidad,recepcion_linea_id,referencia,observaciones)
    values(v_temporada,v_articulo,v_talla,'recepcion',new.cantidad_aceptada,new.id,
           'Recepcion '||new.recepcion_id::text,new.observaciones);
  end if;

  perform private.equipacion_recalcular_estado_pedido(v_pedido_linea);
  return new;
end $$;

drop trigger if exists equipacion_recepcion_lineas_aplicar_stock on public.equipacion_recepcion_lineas;
create trigger equipacion_recepcion_lineas_aplicar_stock
after insert on public.equipacion_recepcion_lineas
for each row execute function private.equipacion_aplicar_recepcion_linea();

create or replace function private.equipacion_recepcion_linea_inmutable()
returns trigger language plpgsql as $$ begin raise exception 'Reception lines are immutable; use a compensating stock adjustment'; end $$;
drop trigger if exists equipacion_recepcion_lineas_no_update on public.equipacion_recepcion_lineas;
drop trigger if exists equipacion_recepcion_lineas_no_delete on public.equipacion_recepcion_lineas;
create trigger equipacion_recepcion_lineas_no_update before update on public.equipacion_recepcion_lineas for each row execute function private.equipacion_recepcion_linea_inmutable();
create trigger equipacion_recepcion_lineas_no_delete before delete on public.equipacion_recepcion_lineas for each row execute function private.equipacion_recepcion_linea_inmutable();

-- Record deliveries in the immutable stock ledger too.
create or replace function private.equipacion_confirmar_entrega(p_asignacion uuid,p_usuario uuid default null)
returns uuid language plpgsql security definer set search_path=public,private as $$
declare arow public.equipacion_asignaciones%rowtype; nrow public.equipacion_necesidades%rowtype; eid uuid;
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  select * into arow from public.equipacion_asignaciones where id=p_asignacion for update;
  if arow.estado='entregada' then select id into eid from public.equipacion_entregas where asignacion_id=p_asignacion; return eid; end if;
  if arow.estado<>'reservada' then raise exception 'Assignment must be reserved before delivery'; end if;
  select * into nrow from public.equipacion_necesidades where id=arow.necesidad_id;
  update public.equipacion_stock set cantidad_fisica=cantidad_fisica-arow.cantidad,cantidad_reservada=cantidad_reservada-arow.cantidad,updated_at=now()
   where temporada_id=nrow.temporada_id and articulo_id=arow.articulo_id and talla=arow.talla and cantidad_reservada>=arow.cantidad;
  if not found then raise exception 'Reserved stock is inconsistent'; end if;
  insert into public.equipacion_entregas(asignacion_id,cantidad,entregada_por) values(p_asignacion,arow.cantidad,p_usuario) returning id into eid;
  insert into public.equipacion_movimientos_stock(temporada_id,articulo_id,talla,tipo,cantidad,asignacion_id,referencia,creado_por)
    values(nrow.temporada_id,arow.articulo_id,arow.talla,'entrega',-arow.cantidad,arow.id,'Entrega '||eid::text,p_usuario);
  update public.equipacion_asignaciones set estado='entregada',updated_at=now() where id=p_asignacion;
  return eid;
end $$;

-- Correct purchase aggregation for any number of simultaneous active orders.
create or replace view public.equipacion_compra_sugerida as
with d as (
  select temporada_id,articulo_id,talla,sum(cantidad_demandada)::integer demanda
  from public.equipacion_demanda_logistica group by 1,2,3
), e as (
  select n.temporada_id,a.articulo_id,a.talla,sum(en.cantidad)::integer entregado
  from public.equipacion_entregas en join public.equipacion_asignaciones a on a.id=en.asignacion_id
  join public.equipacion_necesidades n on n.id=a.necesidad_id group by 1,2,3
), accepted as (
  select rl.pedido_linea_id,sum(rl.cantidad_aceptada)::integer aceptada
  from public.equipacion_recepcion_lineas rl group by rl.pedido_linea_id
), p as (
  select pe.temporada_id,pl.articulo_id,pl.talla,
         sum(greatest(pl.cantidad_pedida-coalesce(ac.aceptada,0),0))::integer pendiente_proveedor
  from public.equipacion_pedidos pe join public.equipacion_pedido_lineas pl on pl.pedido_id=pe.id
  left join accepted ac on ac.pedido_linea_id=pl.id
  where pe.estado in ('pedido','parcialmente_recibido')
  group by 1,2,3
)
select d.temporada_id,d.articulo_id,d.talla,d.demanda,coalesce(e.entregado,0) entregado,
       coalesce(s.cantidad_fisica,0) stock_fisico,coalesce(s.cantidad_reservada,0) reservado,
       coalesce(p.pendiente_proveedor,0) pendiente_proveedor,
       greatest(d.demanda-coalesce(e.entregado,0)-coalesce(s.cantidad_fisica,0)-coalesce(p.pendiente_proveedor,0),0)::integer falta_comprar
from d left join e using(temporada_id,articulo_id,talla)
left join public.equipacion_stock s using(temporada_id,articulo_id,talla)
left join p using(temporada_id,articulo_id,talla);

alter table public.equipacion_movimientos_stock enable row level security;
drop policy if exists equipacion_movimientos_stock_club_manage on public.equipacion_movimientos_stock;
create policy equipacion_movimientos_stock_club_manage on public.equipacion_movimientos_stock to authenticated
using (private.has_any_role(array['administrador','club'])) with check (private.has_any_role(array['administrador','club']));
grant select,insert on public.equipacion_movimientos_stock to authenticated;
grant all on public.equipacion_movimientos_stock to service_role;
revoke all on public.equipacion_movimientos_stock from anon;
grant execute on function private.equipacion_recalcular_estado_pedido(uuid) to authenticated,service_role;

commit;
