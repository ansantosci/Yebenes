-- 074 - Equipment delivery economic control: equipment-specific balance, no overpayment,
-- and immutable debt snapshot when Club/Admin delivers despite pending debt.
begin;

alter table public.equipacion_entregas
  add column if not exists cargo_equipacion_id uuid references public.economia_cargos(id) on delete restrict,
  add column if not exists deuda_pendiente_al_entregar numeric(10,2) not null default 0
    check (deuda_pendiente_al_entregar>=0),
  add column if not exists entregada_con_deuda boolean not null default false,
  add column if not exists deuda_autorizada_por uuid references auth.users(id) on delete restrict,
  add column if not exists deuda_advertida_at timestamptz;

alter table public.equipacion_entregas
  drop constraint if exists equipacion_entregas_deuda_snapshot_ck;
alter table public.equipacion_entregas
  add constraint equipacion_entregas_deuda_snapshot_ck check (
    (entregada_con_deuda=false and deuda_pendiente_al_entregar=0 and deuda_autorizada_por is null and deuda_advertida_at is null)
    or
    (entregada_con_deuda=true and deuda_pendiente_al_entregar>0 and deuda_autorizada_por is not null and deuda_advertida_at is not null)
  );

-- One active equipment charge per need. Returns null/zero when no equipment charge exists.
create or replace function private.equipacion_cargo_estado(p_necesidad uuid)
returns table(cargo_id uuid,importe_exigible numeric,importe_pagado numeric,saldo_pendiente numeric,estado_pago text)
language sql stable security definer set search_path='' as $$
 select e.cargo_id,e.importe_exigible,e.importe_pagado,greatest(e.saldo_pendiente,0)::numeric,e.estado_pago
 from public.economia_cargos c
 join public.economia_estado_cargos e on e.cargo_id=c.id
 where c.equipacion_necesidad_id=p_necesidad and c.origen='equipacion' and c.estado='activo'
 order by c.created_at desc,c.id
 limit 1
$$;

-- Reparto-specific payment: must target the equipment charge for the need and cannot overpay it.
create or replace function private.equipacion_registrar_pago(
 p_necesidad uuid,p_importe numeric,p_metodo text,p_fecha date default current_date,
 p_referencia text default null,p_observaciones text default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); ce record; pid uuid;
begin
 if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
 select * into ce from private.equipacion_cargo_estado(p_necesidad);
 if ce.cargo_id is null then raise exception 'Active equipment charge not found for need'; end if;
 if p_importe is null or p_importe<=0 then raise exception 'Payment amount must be positive'; end if;
 if ce.saldo_pendiente<=0 then raise exception 'Equipment charge is already paid'; end if;
 if p_importe>ce.saldo_pendiente then
   raise exception 'Equipment payment exceeds pending balance: maximum %',ce.saldo_pendiente;
 end if;
 pid:=private.economia_registrar_pago(ce.cargo_id,p_importe,p_metodo,p_fecha,p_referencia,p_observaciones);
 return pid;
end $$;

-- Preserve the existing RPC signature. Delivery never blocks on debt; the debt snapshot is
-- stored automatically so the UI can warn and history remains explainable after later payment.
create or replace function private.equipacion_confirmar_entrega(p_asignacion uuid,p_usuario uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare a public.equipacion_asignaciones%rowtype; n public.equipacion_necesidades%rowtype; eid uuid;
        al record; total integer; actor uuid:=coalesce(p_usuario,auth.uid()); ce record;
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  select * into a from public.equipacion_asignaciones where id=p_asignacion for update;
  if a.id is null then raise exception 'Assignment not found'; end if;
  if a.estado='entregada' then select id into eid from public.equipacion_entregas where asignacion_id=a.id; return eid; end if;
  if a.estado<>'reservada' then raise exception 'Assignment must be fully reserved before delivery'; end if;
  select * into n from public.equipacion_necesidades where id=a.necesidad_id;
  select coalesce(sum(cantidad),0) into total from public.equipacion_asignacion_lotes where asignacion_id=a.id and estado='reservada';
  if total<>a.cantidad then raise exception 'Lot reservations do not cover assignment quantity'; end if;

  select * into ce from private.equipacion_cargo_estado(n.id);
  insert into public.equipacion_entregas(
    asignacion_id,cantidad,entregada_por,cargo_equipacion_id,deuda_pendiente_al_entregar,
    entregada_con_deuda,deuda_autorizada_por,deuda_advertida_at)
  values(
    a.id,a.cantidad,actor,ce.cargo_id,coalesce(ce.saldo_pendiente,0),
    coalesce(ce.saldo_pendiente,0)>0,
    case when coalesce(ce.saldo_pendiente,0)>0 then actor else null end,
    case when coalesce(ce.saldo_pendiente,0)>0 then now() else null end)
  returning id into eid;

  for al in select * from public.equipacion_asignacion_lotes where asignacion_id=a.id and estado='reservada' for update
  loop
    update public.equipacion_stock_lotes
      set cantidad_fisica=cantidad_fisica-al.cantidad,cantidad_reservada=cantidad_reservada-al.cantidad,updated_at=now()
      where id=al.lote_id and cantidad_fisica>=al.cantidad and cantidad_reservada>=al.cantidad;
    if not found then raise exception 'Reserved lot stock is inconsistent'; end if;
    update public.equipacion_asignacion_lotes set estado='entregada',entregado_at=now(),updated_at=now() where id=al.id;
  end loop;
  insert into public.equipacion_movimientos_stock(temporada_id,articulo_id,talla,tipo,cantidad,asignacion_id,referencia,creado_por)
  values(n.temporada_id,a.articulo_id,a.talla,'entrega',-a.cantidad,a.id,'Entrega '||eid::text,actor);
  update public.equipacion_asignaciones set estado='entregada',updated_at=now() where id=a.id;
  perform private.equipacion_recalcular_stock_legacy(n.temporada_id,a.articulo_id,a.talla);
  return eid;
end $$;

revoke all on function private.equipacion_cargo_estado(uuid),private.equipacion_registrar_pago(uuid,numeric,text,date,text,text) from public,anon;
grant execute on function private.equipacion_cargo_estado(uuid),private.equipacion_registrar_pago(uuid,numeric,text,date,text,text) to authenticated,service_role;

commit;
