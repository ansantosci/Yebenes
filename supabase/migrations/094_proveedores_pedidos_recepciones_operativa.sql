-- 094_proveedores_pedidos_recepciones_operativa.sql
-- V96.4.0 backend: provider/brand management + atomic orders/receptions + traceable initial stock.
-- Extends the reusable provider master introduced by 062. No production master data is inserted.
begin;

-- 1. Extend reusable provider master; keep public.equipacion_proveedores for 062 compatibility.
alter table public.equipacion_proveedores
  add column if not exists nombre_fiscal text,
  add column if not exists nif text,
  add column if not exists email text,
  add column if not exists telefono text,
  add column if not exists integracion_tipo text not null default 'manual';

alter table public.equipacion_proveedores drop constraint if exists equipacion_proveedores_integracion_tipo_check;
alter table public.equipacion_proveedores add constraint equipacion_proveedores_integracion_tipo_check
  check (integracion_tipo in ('manual','csv','api'));

drop trigger if exists equipacion_proveedores_updated_at on public.equipacion_proveedores;
create trigger equipacion_proveedores_updated_at before update on public.equipacion_proveedores
for each row execute function public.set_updated_at();

-- Brand is independent from supplier. The same company may exist in both masters.
create table if not exists public.marcas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  activo boolean not null default true,
  observaciones text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (btrim(nombre) <> '')
);
create unique index if not exists marcas_nombre_ci_uq on public.marcas(lower(btrim(nombre)));
drop trigger if exists marcas_updated_at on public.marcas;
create trigger marcas_updated_at before update on public.marcas
for each row execute function public.set_updated_at();

-- Which providers are enabled for a season/scope. Inactive historical providers remain selectable
-- for historical stock, but not for new orders.
create table if not exists public.equipacion_proveedor_temporadas (
  id uuid primary key default gen_random_uuid(),
  proveedor_id uuid not null references public.equipacion_proveedores(id) on delete restrict,
  temporada_id uuid not null references public.temporadas(id) on delete restrict,
  ambito text not null default 'equipaciones',
  principal boolean not null default false,
  activo boolean not null default true,
  observaciones text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (btrim(ambito) <> ''),
  unique (proveedor_id,temporada_id,ambito)
);
create unique index if not exists equipacion_proveedor_temporadas_principal_uq
  on public.equipacion_proveedor_temporadas(temporada_id,ambito)
  where principal and activo;
drop trigger if exists equipacion_proveedor_temporadas_updated_at on public.equipacion_proveedor_temporadas;
create trigger equipacion_proveedor_temporadas_updated_at before update on public.equipacion_proveedor_temporadas
for each row execute function public.set_updated_at();

-- Structured provenance while retaining textual snapshots for historical readability.
alter table public.equipacion_config_temporada
  add column if not exists proveedor_id uuid references public.equipacion_proveedores(id) on delete restrict;
alter table public.equipacion_articulos
  add column if not exists marca_id uuid references public.marcas(id) on delete restrict;
alter table public.equipacion_pedidos
  add column if not exists proveedor_id uuid references public.equipacion_proveedores(id) on delete restrict,
  add column if not exists referencia_externa text,
  add column if not exists estado_externo text,
  add column if not exists sincronizado_at timestamptz;
alter table public.equipacion_pedido_lineas
  add column if not exists origen text not null default 'manual';
alter table public.equipacion_pedido_lineas drop constraint if exists equipacion_pedido_lineas_origen_check;
alter table public.equipacion_pedido_lineas add constraint equipacion_pedido_lineas_origen_check
  check (origen in ('sugerida','manual'));
alter table public.equipacion_stock_lotes
  add column if not exists proveedor_id uuid references public.equipacion_proveedores(id) on delete restrict,
  add column if not exists marca_id uuid references public.marcas(id) on delete restrict;

-- 081 was too restrictive for two different players sharing size+dorsal in one order.
drop index if exists public.equipacion_pedido_lineas_dorsal_uq;
create unique index if not exists equipacion_pedido_lineas_personalizada_uq
  on public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,jugador_id)
  where dorsal is not null;

-- Initial/manual stock is a first-class auditable movement, never a silent lot insert.
alter table public.equipacion_movimientos_stock drop constraint if exists equipacion_movimientos_stock_tipo_check;
alter table public.equipacion_movimientos_stock add constraint equipacion_movimientos_stock_tipo_check
  check (tipo in ('recepcion','entrega','ajuste_positivo','ajuste_negativo','traspaso_entrada','traspaso_salida','inventario_inicial'));
alter table public.equipacion_movimientos_stock drop constraint if exists equipacion_movimientos_stock_check;
alter table public.equipacion_movimientos_stock add constraint equipacion_movimientos_stock_check check (
  (tipo='recepcion' and cantidad > 0 and recepcion_linea_id is not null)
  or (tipo='entrega' and cantidad < 0 and asignacion_id is not null)
  or (tipo='inventario_inicial' and cantidad > 0 and recepcion_linea_id is null and asignacion_id is null)
  or tipo in ('ajuste_positivo','ajuste_negativo','traspaso_entrada','traspaso_salida')
);

-- 2. RLS/ACL for new master data. Existing provider RLS from 062 remains Club/Admin.
alter table public.marcas enable row level security;
alter table public.equipacion_proveedor_temporadas enable row level security;
drop policy if exists marcas_club_manage on public.marcas;
create policy marcas_club_manage on public.marcas to authenticated
using (private.has_any_role(array['administrador','club']))
with check (private.has_any_role(array['administrador','club']));
drop policy if exists equipacion_proveedor_temporadas_club_manage on public.equipacion_proveedor_temporadas;
create policy equipacion_proveedor_temporadas_club_manage on public.equipacion_proveedor_temporadas to authenticated
using (private.has_any_role(array['administrador','club']))
with check (private.has_any_role(array['administrador','club']));
grant select,insert,update,delete on public.marcas,public.equipacion_proveedor_temporadas to authenticated;
grant all on public.marcas,public.equipacion_proveedor_temporadas to service_role;
revoke all on public.marcas,public.equipacion_proveedor_temporadas from anon;

-- 3. Exactly one lot per accepted reception line. Generic path ignores personalized lines.
create or replace function private.equipacion_crear_lote_recepcion()
returns trigger language plpgsql security definer set search_path to '' as $$
declare pe public.equipacion_pedidos%rowtype; pl public.equipacion_pedido_lineas%rowtype;
        r public.equipacion_recepciones%rowtype; lid uuid; v_marca uuid;
begin
  if new.cantidad_aceptada<=0 then return new; end if;
  select * into r from public.equipacion_recepciones where id=new.recepcion_id;
  select * into pl from public.equipacion_pedido_lineas where id=new.pedido_linea_id;
  select * into pe from public.equipacion_pedidos where id=pl.pedido_id;
  if pl.dorsal is not null then return new; end if;
  select marca_id into v_marca from public.equipacion_articulos where id=pl.articulo_id;
  insert into public.equipacion_stock_lotes(
    articulo_id,talla,temporada_origen_id,proveedor_id,proveedor_nombre,marca_id,
    referencia_proveedor,cantidad_fisica,cantidad_reservada,recepcion_linea_id)
  values(pl.articulo_id,pl.talla,pe.temporada_id,pe.proveedor_id,pe.proveedor_nombre,v_marca,
         coalesce(r.referencia,pe.numero),new.cantidad_aceptada,0,new.id)
  on conflict(recepcion_linea_id) where recepcion_linea_id is not null do nothing returning id into lid;
  if lid is not null then
    insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,observaciones)
    values(lid,pe.temporada_id,'valido',now(),'Vigencia automatica de temporada origen')
    on conflict(lote_id,temporada_id) do nothing;
    perform private.equipacion_recalcular_stock_legacy(pe.temporada_id,pl.articulo_id,pl.talla);
  end if;
  return new;
end $$;

create or replace function private.equipacion_aplicar_recepcion_linea_lote_personalizado()
returns trigger language plpgsql security definer set search_path to '' as $$
declare lid uuid; tid uuid; aid uuid; vtalla text; dor integer; jid uuid;
        prov text; prov_id uuid; marca uuid;
begin
  if new.cantidad_aceptada<=0 then return new; end if;
  select pe.temporada_id,pl.articulo_id,pl.talla,pl.dorsal,pl.jugador_id,
         pe.proveedor_nombre,pe.proveedor_id,a.marca_id
    into tid,aid,vtalla,dor,jid,prov,prov_id,marca
  from public.equipacion_pedido_lineas pl
  join public.equipacion_pedidos pe on pe.id=pl.pedido_id
  join public.equipacion_articulos a on a.id=pl.articulo_id
  where pl.id=new.pedido_linea_id;
  if dor is null then return new; end if;
  insert into public.equipacion_stock_lotes(
    articulo_id,talla,temporada_origen_id,proveedor_id,proveedor_nombre,marca_id,
    referencia_proveedor,cantidad_fisica,cantidad_reservada,dorsal,jugador_origen_id,recepcion_linea_id)
  values(aid,vtalla,tid,prov_id,prov,marca,coalesce((select referencia from public.equipacion_recepciones where id=new.recepcion_id),'RECEPCION:'||new.id::text),
         new.cantidad_aceptada,0,dor,jid,new.id)
  on conflict(recepcion_linea_id) where recepcion_linea_id is not null do nothing returning id into lid;
  if lid is not null then
    insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at)
    values(lid,tid,'valido',now()) on conflict(lote_id,temporada_id) do nothing;
    perform private.equipacion_recalcular_stock_legacy(tid,aid,vtalla);
  end if;
  return new;
end $$;
revoke all on function private.equipacion_crear_lote_recepcion() from public,anon,authenticated;
revoke all on function private.equipacion_aplicar_recepcion_linea_lote_personalizado() from public,anon,authenticated;
grant execute on function private.equipacion_crear_lote_recepcion() to service_role;

-- 4. Save/create complete draft atomically. Lines JSON:
-- {articulo_id,talla,cantidad,precio_unitario?,jugador_id?,dorsal?,origen?}
create or replace function public.equipacion_guardar_pedido_borrador(
  p_temporada_id uuid,p_proveedor_id uuid,p_lineas jsonb,p_pedido_id uuid default null,
  p_numero text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path to '' as $$
declare
  v_actor uuid:=auth.uid(); v_id uuid; v_proveedor public.equipacion_proveedores%rowtype;
  v_row jsonb; v_art uuid; v_talla text; v_cantidad integer; v_precio numeric;
  v_jugador uuid; v_dorsal integer; v_origen text; v_personalizable boolean; v_count integer:=0;
begin
  if v_actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  if p_temporada_id is null or p_proveedor_id is null then raise exception 'Season and supplier are required'; end if;
  if p_lineas is null or jsonb_typeof(p_lineas)<>'array' or jsonb_array_length(p_lineas)=0 then raise exception 'Order draft requires at least one line'; end if;
  select * into v_proveedor from public.equipacion_proveedores where id=p_proveedor_id and activo for share;
  if v_proveedor.id is null then raise exception 'Active supplier not found'; end if;
  if not exists(select 1 from public.equipacion_proveedor_temporadas pt
                where pt.proveedor_id=p_proveedor_id and pt.temporada_id=p_temporada_id
                  and pt.ambito='equipaciones' and pt.activo) then
    raise exception 'Supplier is not enabled for equipment in this season';
  end if;
  if p_pedido_id is null then
    insert into public.equipacion_pedidos(temporada_id,numero,proveedor_id,proveedor_nombre,proveedor_contacto,fecha_pedido,estado,observaciones,creado_por)
    values(p_temporada_id,nullif(btrim(p_numero),''),v_proveedor.id,v_proveedor.nombre,
           coalesce(v_proveedor.contacto,v_proveedor.email,v_proveedor.telefono),current_date,'borrador',p_observaciones,v_actor)
    returning id into v_id;
  else
    select id into v_id from public.equipacion_pedidos where id=p_pedido_id and estado='borrador' for update;
    if v_id is null then raise exception 'Only draft orders can be edited'; end if;
    if not exists(select 1 from public.equipacion_pedidos where id=v_id and temporada_id=p_temporada_id) then raise exception 'Order season cannot change'; end if;
    update public.equipacion_pedidos set numero=nullif(btrim(p_numero),''),proveedor_id=v_proveedor.id,
      proveedor_nombre=v_proveedor.nombre,proveedor_contacto=coalesce(v_proveedor.contacto,v_proveedor.email,v_proveedor.telefono),
      observaciones=p_observaciones,updated_at=now() where id=v_id;
    delete from public.equipacion_pedido_lineas where pedido_id=v_id;
  end if;
  for v_row in select value from jsonb_array_elements(p_lineas) loop
    v_count:=v_count+1;
    begin
      v_art:=(v_row->>'articulo_id')::uuid; v_cantidad:=(v_row->>'cantidad')::integer;
      v_precio:=nullif(v_row->>'precio_unitario','')::numeric; v_jugador:=nullif(v_row->>'jugador_id','')::uuid;
      v_dorsal:=nullif(v_row->>'dorsal','')::integer;
    exception when others then raise exception 'Invalid order line payload at position %',v_count; end;
    v_talla:=coalesce(nullif(btrim(v_row->>'talla'),''),'SIN_TALLA');
    v_origen:=coalesce(nullif(btrim(v_row->>'origen'),''),'manual');
    if v_cantidad is null or v_cantidad<=0 then raise exception 'Line % quantity must be positive',v_count; end if;
    if v_origen not in ('sugerida','manual') then raise exception 'Line % origin is invalid',v_count; end if;
    select personalizable_dorsal into v_personalizable from public.equipacion_articulos where id=v_art and activo;
    if v_personalizable is null then raise exception 'Line % article not found/active',v_count; end if;
    if v_personalizable then
      if v_jugador is null or v_dorsal is null or v_cantidad<>1 then raise exception 'Line % personalized garment requires player, dorsal and quantity 1',v_count; end if;
    else
      if v_jugador is not null or v_dorsal is not null then raise exception 'Line % non-personalized article cannot carry player/dorsal',v_count; end if;
    end if;
    insert into public.equipacion_pedido_lineas(pedido_id,articulo_id,talla,cantidad_pedida,precio_unitario,jugador_id,dorsal,origen)
    values(v_id,v_art,v_talla,v_cantidad,v_precio,v_jugador,v_dorsal,v_origen);
  end loop;
  return v_id;
end $$;

create or replace function public.equipacion_cursar_pedido(p_pedido_id uuid)
returns uuid language plpgsql security definer set search_path to '' as $$
declare v_actor uuid:=auth.uid(); v_pedido public.equipacion_pedidos%rowtype; v_lineas integer;
begin
  if v_actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  select * into v_pedido from public.equipacion_pedidos where id=p_pedido_id for update;
  if v_pedido.id is null then raise exception 'Order not found'; end if;
  if v_pedido.estado<>'borrador' then raise exception 'Only draft orders can be placed'; end if;
  if v_pedido.proveedor_id is null then raise exception 'Structured supplier is required before placing order'; end if;
  select count(*) into v_lineas from public.equipacion_pedido_lineas where pedido_id=p_pedido_id;
  if v_lineas=0 then raise exception 'Order has no lines'; end if;
  update public.equipacion_pedido_lineas set updated_at=updated_at where pedido_id=p_pedido_id;
  update public.equipacion_pedidos set estado='pedido',fecha_pedido=current_date,updated_at=now() where id=p_pedido_id;
  return p_pedido_id;
end $$;

create or replace function public.equipacion_registrar_recepcion_pedido(
  p_pedido_id uuid,p_lineas jsonb,p_fecha_recepcion date default current_date,
  p_referencia text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path to '' as $$
declare v_actor uuid:=auth.uid(); v_recepcion uuid; v_row jsonb; v_linea uuid;
        v_recibida integer; v_aceptada integer; v_obs text; v_pos integer:=0;
begin
  if v_actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  if not exists(select 1 from public.equipacion_pedidos where id=p_pedido_id and estado in ('pedido','parcialmente_recibido') for update) then
    raise exception 'Reception requires an ordered or partially received order'; end if;
  if p_lineas is null or jsonb_typeof(p_lineas)<>'array' or jsonb_array_length(p_lineas)=0 then raise exception 'Reception requires at least one line'; end if;
  insert into public.equipacion_recepciones(pedido_id,fecha_recepcion,referencia,observaciones,recibido_por)
  values(p_pedido_id,coalesce(p_fecha_recepcion,current_date),nullif(btrim(p_referencia),''),p_observaciones,v_actor) returning id into v_recepcion;
  for v_row in select value from jsonb_array_elements(p_lineas) loop
    v_pos:=v_pos+1;
    begin
      v_linea:=(v_row->>'pedido_linea_id')::uuid; v_recibida:=(v_row->>'cantidad_recibida')::integer; v_aceptada:=(v_row->>'cantidad_aceptada')::integer;
    exception when others then raise exception 'Invalid reception line payload at position %',v_pos; end;
    v_obs:=nullif(btrim(v_row->>'observaciones'),'');
    if v_recibida is null or v_recibida<=0 then raise exception 'Reception line % received quantity must be positive',v_pos; end if;
    if v_aceptada is null or v_aceptada<0 or v_aceptada>v_recibida then raise exception 'Reception line % accepted quantity is invalid',v_pos; end if;
    if not exists(select 1 from public.equipacion_pedido_lineas where id=v_linea and pedido_id=p_pedido_id) then raise exception 'Reception line % does not belong to order',v_pos; end if;
    insert into public.equipacion_recepcion_lineas(recepcion_id,pedido_linea_id,cantidad_recibida,cantidad_aceptada,observaciones)
    values(v_recepcion,v_linea,v_recibida,v_aceptada,v_obs);
  end loop;
  return v_recepcion;
end $$;

-- 5. Register stock already owned by the Club. Inactive historical provider/brand are allowed.
create or replace function public.equipacion_registrar_stock_existente(
  p_articulo_id uuid,p_talla text,p_cantidad integer,p_temporada_origen_id uuid,p_temporada_vigencia_id uuid,
  p_proveedor_id uuid default null,p_marca_id uuid default null,p_vigencia text default 'valido',
  p_referencia text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path to '' as $$
declare v_actor uuid:=auth.uid(); v_lote uuid; v_proveedor_nombre text;
begin
  if v_actor is null or not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;
  if p_articulo_id is null or not exists(select 1 from public.equipacion_articulos where id=p_articulo_id) then raise exception 'Article not found'; end if;
  if p_cantidad is null or p_cantidad<=0 then raise exception 'Initial stock quantity must be positive'; end if;
  if p_temporada_origen_id is null or not exists(select 1 from public.temporadas where id=p_temporada_origen_id) then raise exception 'Origin season is required'; end if;
  if p_temporada_vigencia_id is null or not exists(select 1 from public.temporadas where id=p_temporada_vigencia_id) then raise exception 'Validity season is required'; end if;
  if p_vigencia not in ('pendiente','valido','no_valido') then raise exception 'Invalid lot validity'; end if;
  if p_proveedor_id is not null then
    select nombre into v_proveedor_nombre from public.equipacion_proveedores where id=p_proveedor_id;
    if v_proveedor_nombre is null then raise exception 'Supplier not found'; end if;
  end if;
  if p_marca_id is not null and not exists(select 1 from public.marcas where id=p_marca_id) then raise exception 'Brand not found'; end if;
  insert into public.equipacion_stock_lotes(articulo_id,talla,temporada_origen_id,proveedor_id,proveedor_nombre,marca_id,
    referencia_proveedor,cantidad_fisica,cantidad_reservada)
  values(p_articulo_id,coalesce(nullif(btrim(p_talla),''),'SIN_TALLA'),p_temporada_origen_id,p_proveedor_id,v_proveedor_nombre,p_marca_id,
    nullif(btrim(p_referencia),''),p_cantidad,0) returning id into v_lote;
  insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,decidido_por,observaciones)
  values(v_lote,p_temporada_vigencia_id,p_vigencia,case when p_vigencia='pendiente' then null else now() end,
    case when p_vigencia='pendiente' then null else v_actor end,p_observaciones);
  insert into public.equipacion_movimientos_stock(temporada_id,articulo_id,talla,tipo,cantidad,referencia,observaciones,creado_por)
  values(p_temporada_origen_id,p_articulo_id,coalesce(nullif(btrim(p_talla),''),'SIN_TALLA'),'inventario_inicial',p_cantidad,
    coalesce(nullif(btrim(p_referencia),''),'Inventario inicial '||v_lote::text),p_observaciones,v_actor);
  if p_vigencia='valido' then perform private.equipacion_recalcular_stock_legacy(p_temporada_vigencia_id,p_articulo_id,coalesce(nullif(btrim(p_talla),''),'SIN_TALLA')); end if;
  return v_lote;
end $$;

-- Public callable surface: signed-in Club/Admin only; authorization is repeated inside each RPC.
revoke all on function public.equipacion_guardar_pedido_borrador(uuid,uuid,jsonb,uuid,text,text) from public,anon;
revoke all on function public.equipacion_cursar_pedido(uuid) from public,anon;
revoke all on function public.equipacion_registrar_recepcion_pedido(uuid,jsonb,date,text,text) from public,anon;
revoke all on function public.equipacion_registrar_stock_existente(uuid,text,integer,uuid,uuid,uuid,uuid,text,text,text) from public,anon;
grant execute on function public.equipacion_guardar_pedido_borrador(uuid,uuid,jsonb,uuid,text,text) to authenticated,service_role;
grant execute on function public.equipacion_cursar_pedido(uuid) to authenticated,service_role;
grant execute on function public.equipacion_registrar_recepcion_pedido(uuid,jsonb,date,text,text) to authenticated,service_role;
grant execute on function public.equipacion_registrar_stock_existente(uuid,text,integer,uuid,uuid,uuid,uuid,text,text,text) to authenticated,service_role;

commit;
