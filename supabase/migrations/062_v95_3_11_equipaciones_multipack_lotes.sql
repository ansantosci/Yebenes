-- 062 - Equipaciones: multipack needs, providers, lot-backed reservations and audited stock.
begin;

-- Providers are reusable master data. Orders keep their textual snapshot for history.
create table if not exists public.equipacion_proveedores (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  contacto text,
  url text,
  activo boolean not null default true,
  observaciones text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists equipacion_proveedores_nombre_uq
  on public.equipacion_proveedores(lower(nombre));

alter table public.equipacion_packs
  add column if not exists proveedor_id uuid references public.equipacion_proveedores(id) on delete set null;

-- One person/facet/season may need several packs, but never the same pack twice.
alter table public.equipacion_necesidades drop constraint if exists equipacion_necesidades_temporada_id_faceta_jugador_id_key;
alter table public.equipacion_necesidades drop constraint if exists equipacion_necesidades_temporada_id_faceta_entrenador_id_key;
create unique index if not exists equipacion_necesidades_jugador_pack_uq
  on public.equipacion_necesidades(temporada_id,faceta,jugador_id,pack_id)
  where jugador_id is not null and pack_id is not null;
create unique index if not exists equipacion_necesidades_entrenador_pack_uq
  on public.equipacion_necesidades(temporada_id,faceta,entrenador_id,pack_id)
  where entrenador_id is not null and pack_id is not null;

create or replace function private.equipacion_validar_pack_necesidad()
returns trigger language plpgsql set search_path='' as $$
declare p public.equipacion_packs%rowtype;
begin
  if new.pack_id is null then return new; end if;
  select * into p from public.equipacion_packs where id=new.pack_id;
  if p.id is null then raise exception 'Equipment pack not found'; end if;
  if p.temporada_id<>new.temporada_id then raise exception 'Equipment pack and need must belong to the same season'; end if;
  if (new.faceta='jugador' and p.destinatario<>'jugador') or
     (new.faceta='entrenador' and p.destinatario<>'entrenador') then
    raise exception 'Equipment pack recipient does not match need facet';
  end if;
  return new;
end $$;
drop trigger if exists equipacion_necesidad_pack_guard on public.equipacion_necesidades;
create trigger equipacion_necesidad_pack_guard
before insert or update of pack_id,temporada_id,faceta on public.equipacion_necesidades
for each row execute function private.equipacion_validar_pack_necesidad();

-- Traceability between a logical assignment and one or more physical stock lots.
create table if not exists public.equipacion_asignacion_lotes (
  id uuid primary key default gen_random_uuid(),
  asignacion_id uuid not null references public.equipacion_asignaciones(id) on delete restrict,
  lote_id uuid not null references public.equipacion_stock_lotes(id) on delete restrict,
  cantidad integer not null check (cantidad>0),
  estado text not null default 'reservada' check (estado in ('reservada','entregada','liberada')),
  reservado_at timestamptz not null default now(),
  entregado_at timestamptz,
  liberado_at timestamptz,
  reservado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(asignacion_id,lote_id)
);

-- Every manual stock correction is a first-class immutable audit event.
create table if not exists public.equipacion_ajustes_stock (
  id uuid primary key default gen_random_uuid(),
  lote_id uuid not null references public.equipacion_stock_lotes(id) on delete restrict,
  cantidad_anterior integer not null,
  cantidad_ajuste integer not null check (cantidad_ajuste<>0),
  cantidad_resultante integer not null check (cantidad_resultante>=0),
  motivo text not null check (length(trim(motivo))>0),
  observaciones text,
  ajustado_por uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (cantidad_resultante=cantidad_anterior+cantidad_ajuste)
);

-- Lot provenance from receptions. One accepted reception line creates one lot.
alter table public.equipacion_stock_lotes
  add column if not exists recepcion_linea_id uuid references public.equipacion_recepcion_lineas(id) on delete restrict;
create unique index if not exists equipacion_stock_lotes_recepcion_linea_uq
  on public.equipacion_stock_lotes(recepcion_linea_id) where recepcion_linea_id is not null;

-- Idempotent legacy-stock bootstrap: only create a migration lot when no 062 migration lot exists.
insert into public.equipacion_stock_lotes(
  articulo_id,talla,temporada_origen_id,referencia_proveedor,cantidad_fisica,cantidad_reservada
)
select s.articulo_id,s.talla,s.temporada_id,'MIGRACION_STOCK_062',s.cantidad_fisica,0
from public.equipacion_stock s
where s.cantidad_fisica>0
  and not exists(
    select 1 from public.equipacion_stock_lotes l
    where l.articulo_id=s.articulo_id and l.talla=s.talla
      and l.temporada_origen_id=s.temporada_id and l.referencia_proveedor='MIGRACION_STOCK_062'
  );

insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,observaciones)
select l.id,l.temporada_origen_id,'valido',now(),'Vigencia inicial creada por migracion 062'
from public.equipacion_stock_lotes l
where l.referencia_proveedor='MIGRACION_STOCK_062'
on conflict(lote_id,temporada_id) do nothing;

-- Compatibility aggregate is recalculated from lots valid for their own origin season.
create or replace function private.equipacion_recalcular_stock_legacy(
  p_temporada uuid,p_articulo uuid,p_talla text
) returns void language plpgsql security definer set search_path='' as $$
declare f integer; r integer;
begin
  select coalesce(sum(l.cantidad_fisica),0),coalesce(sum(l.cantidad_reservada),0)
    into f,r
  from public.equipacion_stock_lotes l
  join public.equipacion_stock_lote_vigencia v on v.lote_id=l.id
  where v.temporada_id=p_temporada and v.estado='valido'
    and l.articulo_id=p_articulo and l.talla=p_talla;
  insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
  values(p_temporada,p_articulo,p_talla,f,r)
  on conflict(temporada_id,articulo_id,talla) do update
  set cantidad_fisica=excluded.cantidad_fisica,cantidad_reservada=excluded.cantidad_reservada,updated_at=now();
end $$;

-- Explicit lot reservation. Multiple calls can compose one assignment from several lots.
create or replace function private.equipacion_reservar_asignacion_lote(
  p_asignacion uuid,p_lote uuid,p_cantidad integer
) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.equipacion_asignaciones%rowtype; n public.equipacion_necesidades%rowtype;
        l public.equipacion_stock_lotes%rowtype; rid uuid; total integer;
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  if p_cantidad is null or p_cantidad<=0 then raise exception 'Reservation quantity must be positive'; end if;
  select * into a from public.equipacion_asignaciones where id=p_asignacion for update;
  if a.id is null or a.estado not in ('propuesta','reservada') then raise exception 'Assignment cannot be reserved'; end if;
  select * into n from public.equipacion_necesidades where id=a.necesidad_id;
  select * into l from public.equipacion_stock_lotes where id=p_lote for update;
  if l.id is null or l.articulo_id<>a.articulo_id or l.talla<>a.talla then raise exception 'Lot does not match assignment article/size'; end if;
  if not exists(select 1 from public.equipacion_stock_lote_vigencia v where v.lote_id=l.id and v.temporada_id=n.temporada_id and v.estado='valido')
    then raise exception 'Lot is not valid for need season'; end if;
  select coalesce(sum(al.cantidad),0) into total from public.equipacion_asignacion_lotes al
   where al.asignacion_id=a.id and al.estado='reservada';
  if total+p_cantidad>a.cantidad then raise exception 'Reservation exceeds assignment quantity'; end if;
  if l.cantidad_fisica-l.cantidad_reservada<p_cantidad then raise exception 'Insufficient lot stock'; end if;

  insert into public.equipacion_asignacion_lotes(asignacion_id,lote_id,cantidad,reservado_por)
  values(a.id,l.id,p_cantidad,auth.uid())
  on conflict(asignacion_id,lote_id) do update
    set cantidad=public.equipacion_asignacion_lotes.cantidad+excluded.cantidad,updated_at=now()
  returning id into rid;
  update public.equipacion_stock_lotes set cantidad_reservada=cantidad_reservada+p_cantidad,updated_at=now() where id=l.id;
  select coalesce(sum(cantidad),0) into total from public.equipacion_asignacion_lotes where asignacion_id=a.id and estado='reservada';
  update public.equipacion_asignaciones set estado=case when total=a.cantidad then 'reservada' else 'propuesta' end,
    reservado_at=case when total=a.cantidad then coalesce(reservado_at,now()) else reservado_at end,updated_at=now()
  where id=a.id;
  perform private.equipacion_recalcular_stock_legacy(n.temporada_id,a.articulo_id,a.talla);
  return rid;
end $$;

create or replace function private.equipacion_ajustar_stock_lote(
  p_lote uuid,p_ajuste integer,p_motivo text,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare l public.equipacion_stock_lotes%rowtype; aid uuid; actor uuid:=auth.uid(); tid uuid;
begin
  if actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  if p_ajuste is null or p_ajuste=0 then raise exception 'Stock adjustment cannot be zero'; end if;
  if nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Stock adjustment reason is required'; end if;
  select * into l from public.equipacion_stock_lotes where id=p_lote for update;
  if l.id is null then raise exception 'Stock lot not found'; end if;
  if l.cantidad_fisica+p_ajuste<l.cantidad_reservada then raise exception 'Adjustment cannot reduce physical stock below reserved stock'; end if;
  update public.equipacion_stock_lotes set cantidad_fisica=cantidad_fisica+p_ajuste,updated_at=now() where id=l.id;
  insert into public.equipacion_ajustes_stock(lote_id,cantidad_anterior,cantidad_ajuste,cantidad_resultante,motivo,observaciones,ajustado_por)
  values(l.id,l.cantidad_fisica,p_ajuste,l.cantidad_fisica+p_ajuste,trim(p_motivo),p_observaciones,actor) returning id into aid;
  -- immutable ledger entry; origin season records where the physical stock came from.
  insert into public.equipacion_movimientos_stock(temporada_id,articulo_id,talla,tipo,cantidad,referencia,observaciones,creado_por)
  values(l.temporada_origen_id,l.articulo_id,l.talla,case when p_ajuste>0 then 'ajuste_positivo' else 'ajuste_negativo' end,
         p_ajuste,'Ajuste lote '||l.id::text,trim(p_motivo)||coalesce(' · '||nullif(trim(p_observaciones),''),''),actor);
  for tid in select v.temporada_id from public.equipacion_stock_lote_vigencia v where v.lote_id=l.id and v.estado='valido'
  loop perform private.equipacion_recalcular_stock_legacy(tid,l.articulo_id,l.talla); end loop;
  return aid;
end $$;

-- Delivery now consumes all lot reservations atomically and keeps immutable provenance.
create or replace function private.equipacion_confirmar_entrega(p_asignacion uuid,p_usuario uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare a public.equipacion_asignaciones%rowtype; n public.equipacion_necesidades%rowtype; eid uuid;
        al record; total integer; actor uuid:=coalesce(p_usuario,auth.uid());
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  select * into a from public.equipacion_asignaciones where id=p_asignacion for update;
  if a.estado='entregada' then select id into eid from public.equipacion_entregas where asignacion_id=a.id; return eid; end if;
  if a.estado<>'reservada' then raise exception 'Assignment must be fully reserved before delivery'; end if;
  select * into n from public.equipacion_necesidades where id=a.necesidad_id;
  select coalesce(sum(cantidad),0) into total from public.equipacion_asignacion_lotes where asignacion_id=a.id and estado='reservada';
  if total<>a.cantidad then raise exception 'Lot reservations do not cover assignment quantity'; end if;

  insert into public.equipacion_entregas(asignacion_id,cantidad,entregada_por) values(a.id,a.cantidad,actor) returning id into eid;
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

-- New accepted receptions create a traceable lot; legacy aggregate is then reconciled from lots.
create or replace function private.equipacion_crear_lote_recepcion()
returns trigger language plpgsql security definer set search_path='' as $$
declare pe public.equipacion_pedidos%rowtype; pl public.equipacion_pedido_lineas%rowtype; r public.equipacion_recepciones%rowtype; lid uuid;
begin
  if new.cantidad_aceptada<=0 then return new; end if;
  select * into r from public.equipacion_recepciones where id=new.recepcion_id;
  select * into pl from public.equipacion_pedido_lineas where id=new.pedido_linea_id;
  select * into pe from public.equipacion_pedidos where id=pl.pedido_id;
  insert into public.equipacion_stock_lotes(articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,
    cantidad_fisica,cantidad_reservada,recepcion_linea_id)
  values(pl.articulo_id,pl.talla,pe.temporada_id,pe.proveedor_nombre,coalesce(r.referencia,pe.numero),
    new.cantidad_aceptada,0,new.id)
  on conflict(recepcion_linea_id) do nothing returning id into lid;
  if lid is not null then
    insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,observaciones)
    values(lid,pe.temporada_id,'valido',now(),'Vigencia automatica de temporada origen')
    on conflict(lote_id,temporada_id) do nothing;
    perform private.equipacion_recalcular_stock_legacy(pe.temporada_id,pl.articulo_id,pl.talla);
  end if;
  return new;
end $$;
drop trigger if exists equipacion_recepcion_lineas_crear_lote on public.equipacion_recepcion_lineas;
create trigger equipacion_recepcion_lineas_crear_lote
after insert on public.equipacion_recepcion_lineas
for each row execute function private.equipacion_crear_lote_recepcion();

create or replace view public.equipacion_material_persona as
select n.persona_id,n.temporada_id,n.faceta,n.pack_id,a.id asignacion_id,a.articulo_id,a.talla,
       al.lote_id,al.cantidad,e.entregada_at,e.entregada_por,
       l.temporada_origen_id,l.proveedor_nombre,l.referencia_proveedor
from public.equipacion_necesidades n
join public.equipacion_asignaciones a on a.necesidad_id=n.id and a.estado='entregada'
join public.equipacion_entregas e on e.asignacion_id=a.id
join public.equipacion_asignacion_lotes al on al.asignacion_id=a.id and al.estado='entregada'
join public.equipacion_stock_lotes l on l.id=al.lote_id;

create or replace view public.equipacion_reparto_resumen as
select n.id necesidad_id,n.persona_id,n.temporada_id,n.faceta,n.jugador_id,n.entrenador_id,n.pack_id,
count(a.id)::integer prendas_asignadas,
count(a.id) filter(where a.estado='entregada')::integer prendas_entregadas,
case
 when count(a.id)=0 then 'pendiente'
 when count(a.id) filter(where a.estado='entregada')=count(a.id) then 'entregada'
 when count(a.id) filter(where a.estado='entregada')>0 then 'entrega_parcial'
 when count(a.id) filter(where a.estado='reservada')=count(a.id) then 'preparada'
 when count(a.id) filter(where a.estado='reservada')>0 then 'preparacion_parcial'
 else 'pendiente' end estado_reparto,
count(a.id) filter(where a.estado='reservada')::integer prendas_preparadas
from public.equipacion_necesidades n
left join public.equipacion_asignaciones a on a.necesidad_id=n.id and a.estado<>'cancelada'
group by n.id,n.persona_id,n.temporada_id,n.faceta,n.jugador_id,n.entrenador_id,n.pack_id;

-- Security.
alter table public.equipacion_proveedores enable row level security;
alter table public.equipacion_asignacion_lotes enable row level security;
alter table public.equipacion_ajustes_stock enable row level security;
do $$ declare t text; begin
 foreach t in array array['equipacion_proveedores','equipacion_asignacion_lotes','equipacion_ajustes_stock'] loop
   execute format('drop policy if exists %I_club_manage on public.%I',t,t);
   execute format('create policy %I_club_manage on public.%I to authenticated using (private.has_any_role(array[''administrador'',''club''])) with check (private.has_any_role(array[''administrador'',''club'']))',t,t);
 end loop;
end $$;
grant select,insert,update,delete on public.equipacion_proveedores,public.equipacion_asignacion_lotes to authenticated;
grant select on public.equipacion_ajustes_stock to authenticated;
grant all on public.equipacion_proveedores,public.equipacion_asignacion_lotes,public.equipacion_ajustes_stock to service_role;
revoke all on public.equipacion_proveedores,public.equipacion_asignacion_lotes,public.equipacion_ajustes_stock from anon;
grant select on public.equipacion_material_persona,public.equipacion_reparto_resumen to authenticated,service_role;
revoke all on public.equipacion_material_persona,public.equipacion_reparto_resumen from anon;

revoke all on function private.equipacion_validar_pack_necesidad() from public,anon,authenticated;
revoke all on function private.equipacion_recalcular_stock_legacy(uuid,uuid,text) from public,anon,authenticated;
revoke all on function private.equipacion_crear_lote_recepcion() from public,anon,authenticated;
grant execute on function private.equipacion_validar_pack_necesidad(),private.equipacion_recalcular_stock_legacy(uuid,uuid,text),
  private.equipacion_crear_lote_recepcion() to service_role;
grant execute on function private.equipacion_reservar_asignacion_lote(uuid,uuid,integer),
  private.equipacion_ajustar_stock_lote(uuid,integer,text,text),
  private.equipacion_confirmar_entrega(uuid,uuid) to authenticated,service_role;

commit;
