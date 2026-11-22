-- 105 - Granular Equipment RBAC and server convergence.
begin;

insert into private.capacidades(codigo,nombre,descripcion) values
 ('equipment.stock.manage','Gestionar stock de equipaciones','Gestionar existencias, lotes, movimientos y recepciones.'),
 ('equipment.fulfillment.manage','Gestionar preparación y entrega','Reservar, preparar, entregar, devolver y gestionar necesidades de equipación.'),
 ('equipment.procurement.manage','Gestionar compras de equipaciones','Gestionar proveedores y pedidos de equipación.')
on conflict (codigo) do update set nombre=excluded.nombre,descripcion=excluded.descripcion;

with matrix(rol_codigo, capacidad_codigo) as (values
 ('administrador','equipment.stock.manage'),('administrador','equipment.fulfillment.manage'),('administrador','equipment.procurement.manage'),
 ('club','equipment.stock.manage'),('club','equipment.fulfillment.manage'),('club','equipment.procurement.manage')
)
insert into private.rol_capacidades(rol_id,capacidad_codigo)
select r.id,mx.capacidad_codigo
from matrix mx
join public.roles r on r.codigo=mx.rol_codigo
on conflict do nothing;

drop policy if exists equipacion_articulos_admin_write on public.equipacion_articulos;
drop policy if exists equipacion_articulos_equipment_manage on public.equipacion_articulos;
create policy equipacion_articulos_equipment_manage on public.equipacion_articulos to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_config_admin_write on public.equipacion_config_temporada;
drop policy if exists equipacion_config_temporada_equipment_manage on public.equipacion_config_temporada;
create policy equipacion_config_temporada_equipment_manage on public.equipacion_config_temporada to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_packs_admin_write on public.equipacion_packs;
drop policy if exists equipacion_packs_equipment_manage on public.equipacion_packs;
create policy equipacion_packs_equipment_manage on public.equipacion_packs to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_pack_articulos_admin_write on public.equipacion_pack_articulos;
drop policy if exists equipacion_pack_articulos_equipment_manage on public.equipacion_pack_articulos;
create policy equipacion_pack_articulos_equipment_manage on public.equipacion_pack_articulos to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_necesidades_admin_write on public.equipacion_necesidades;
drop policy if exists equipacion_necesidades_equipment_manage on public.equipacion_necesidades;
create policy equipacion_necesidades_equipment_manage on public.equipacion_necesidades to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_dorsales_admin_write on public.equipacion_dorsales;
drop policy if exists equipacion_dorsales_equipment_manage on public.equipacion_dorsales;
create policy equipacion_dorsales_equipment_manage on public.equipacion_dorsales to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_articulo_precios_club on public.equipacion_articulo_precios_temporada;
drop policy if exists equipacion_articulo_precios_temporada_equipment_manage on public.equipacion_articulo_precios_temporada;
create policy equipacion_articulo_precios_temporada_equipment_manage on public.equipacion_articulo_precios_temporada to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_sistemas_tallaje_insert on public.equipacion_sistemas_tallaje;
drop policy if exists equipacion_sistemas_tallaje_insert_capability on public.equipacion_sistemas_tallaje;
create policy equipacion_sistemas_tallaje_insert_capability on public.equipacion_sistemas_tallaje for insert to authenticated with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_sistemas_tallaje_update on public.equipacion_sistemas_tallaje;
drop policy if exists equipacion_sistemas_tallaje_update_capability on public.equipacion_sistemas_tallaje;
create policy equipacion_sistemas_tallaje_update_capability on public.equipacion_sistemas_tallaje for update to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_sistemas_tallaje_delete on public.equipacion_sistemas_tallaje;
drop policy if exists equipacion_sistemas_tallaje_delete_capability on public.equipacion_sistemas_tallaje;
create policy equipacion_sistemas_tallaje_delete_capability on public.equipacion_sistemas_tallaje for delete to authenticated using (private.has_capability('equipment.manage'));
drop policy if exists equipacion_tallaje_valores_insert on public.equipacion_tallaje_valores;
drop policy if exists equipacion_tallaje_valores_insert_capability on public.equipacion_tallaje_valores;
create policy equipacion_tallaje_valores_insert_capability on public.equipacion_tallaje_valores for insert to authenticated with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_tallaje_valores_update on public.equipacion_tallaje_valores;
drop policy if exists equipacion_tallaje_valores_update_capability on public.equipacion_tallaje_valores;
create policy equipacion_tallaje_valores_update_capability on public.equipacion_tallaje_valores for update to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_tallaje_valores_delete on public.equipacion_tallaje_valores;
drop policy if exists equipacion_tallaje_valores_delete_capability on public.equipacion_tallaje_valores;
create policy equipacion_tallaje_valores_delete_capability on public.equipacion_tallaje_valores for delete to authenticated using (private.has_capability('equipment.manage'));
drop policy if exists equipacion_articulo_tallas_insert on public.equipacion_articulo_tallas;
drop policy if exists equipacion_articulo_tallas_insert_capability on public.equipacion_articulo_tallas;
create policy equipacion_articulo_tallas_insert_capability on public.equipacion_articulo_tallas for insert to authenticated with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_articulo_tallas_update on public.equipacion_articulo_tallas;
drop policy if exists equipacion_articulo_tallas_update_capability on public.equipacion_articulo_tallas;
create policy equipacion_articulo_tallas_update_capability on public.equipacion_articulo_tallas for update to authenticated using (private.has_capability('equipment.manage')) with check (private.has_capability('equipment.manage'));
drop policy if exists equipacion_articulo_tallas_delete on public.equipacion_articulo_tallas;
drop policy if exists equipacion_articulo_tallas_delete_capability on public.equipacion_articulo_tallas;
create policy equipacion_articulo_tallas_delete_capability on public.equipacion_articulo_tallas for delete to authenticated using (private.has_capability('equipment.manage'));
drop policy if exists equipacion_stock_club_manage on public.equipacion_stock;
drop policy if exists equipacion_stock_stock_manage on public.equipacion_stock;
create policy equipacion_stock_stock_manage on public.equipacion_stock to authenticated using (private.has_capability('equipment.stock.manage')) with check (private.has_capability('equipment.stock.manage'));
drop policy if exists equipacion_movimientos_stock_club_manage on public.equipacion_movimientos_stock;
drop policy if exists equipacion_movimientos_stock_stock_manage on public.equipacion_movimientos_stock;
create policy equipacion_movimientos_stock_stock_manage on public.equipacion_movimientos_stock to authenticated using (private.has_capability('equipment.stock.manage')) with check (private.has_capability('equipment.stock.manage'));
drop policy if exists equipacion_stock_lotes_club_manage on public.equipacion_stock_lotes;
drop policy if exists equipacion_stock_lotes_stock_manage on public.equipacion_stock_lotes;
create policy equipacion_stock_lotes_stock_manage on public.equipacion_stock_lotes to authenticated using (private.has_capability('equipment.stock.manage')) with check (private.has_capability('equipment.stock.manage'));
drop policy if exists equipacion_stock_lote_vigencia_club_manage on public.equipacion_stock_lote_vigencia;
drop policy if exists equipacion_stock_lote_vigencia_stock_manage on public.equipacion_stock_lote_vigencia;
create policy equipacion_stock_lote_vigencia_stock_manage on public.equipacion_stock_lote_vigencia to authenticated using (private.has_capability('equipment.stock.manage')) with check (private.has_capability('equipment.stock.manage'));
drop policy if exists equipacion_ajustes_stock_club_manage on public.equipacion_ajustes_stock;
drop policy if exists equipacion_ajustes_stock_stock_manage on public.equipacion_ajustes_stock;
create policy equipacion_ajustes_stock_stock_manage on public.equipacion_ajustes_stock to authenticated using (private.has_capability('equipment.stock.manage')) with check (private.has_capability('equipment.stock.manage'));
drop policy if exists equipacion_asignaciones_club_manage on public.equipacion_asignaciones;
drop policy if exists equipacion_asignaciones_fulfillment_manage on public.equipacion_asignaciones;
create policy equipacion_asignaciones_fulfillment_manage on public.equipacion_asignaciones to authenticated using (private.has_capability('equipment.fulfillment.manage')) with check (private.has_capability('equipment.fulfillment.manage'));
drop policy if exists equipacion_entregas_club_manage on public.equipacion_entregas;
drop policy if exists equipacion_entregas_fulfillment_manage on public.equipacion_entregas;
create policy equipacion_entregas_fulfillment_manage on public.equipacion_entregas to authenticated using (private.has_capability('equipment.fulfillment.manage')) with check (private.has_capability('equipment.fulfillment.manage'));
drop policy if exists equipacion_traspasos_stock_club_manage on public.equipacion_traspasos_stock;
drop policy if exists equipacion_traspasos_stock_fulfillment_manage on public.equipacion_traspasos_stock;
create policy equipacion_traspasos_stock_fulfillment_manage on public.equipacion_traspasos_stock to authenticated using (private.has_capability('equipment.fulfillment.manage')) with check (private.has_capability('equipment.fulfillment.manage'));
drop policy if exists equipacion_asignacion_lotes_club_manage on public.equipacion_asignacion_lotes;
drop policy if exists equipacion_asignacion_lotes_fulfillment_manage on public.equipacion_asignacion_lotes;
create policy equipacion_asignacion_lotes_fulfillment_manage on public.equipacion_asignacion_lotes to authenticated using (private.has_capability('equipment.fulfillment.manage')) with check (private.has_capability('equipment.fulfillment.manage'));
drop policy if exists equipacion_devoluciones_club on public.equipacion_devoluciones;
drop policy if exists equipacion_devoluciones_fulfillment_manage on public.equipacion_devoluciones;
create policy equipacion_devoluciones_fulfillment_manage on public.equipacion_devoluciones to authenticated using (private.has_capability('equipment.fulfillment.manage')) with check (private.has_capability('equipment.fulfillment.manage'));
drop policy if exists equipacion_preparaciones_desplazadas_club on public.equipacion_preparaciones_desplazadas;
drop policy if exists equipacion_preparaciones_desplazadas_fulfillment_manage on public.equipacion_preparaciones_desplazadas;
create policy equipacion_preparaciones_desplazadas_fulfillment_manage on public.equipacion_preparaciones_desplazadas for select to authenticated using (private.has_capability('equipment.fulfillment.manage'));
drop policy if exists equipacion_solicitud_cambios_club on public.equipacion_solicitud_cambios;
drop policy if exists equipacion_solicitud_cambios_fulfillment_manage on public.equipacion_solicitud_cambios;
create policy equipacion_solicitud_cambios_fulfillment_manage on public.equipacion_solicitud_cambios to authenticated using (private.has_capability('equipment.fulfillment.manage')) with check (private.has_capability('equipment.fulfillment.manage'));
drop policy if exists equipacion_proveedores_club_manage on public.equipacion_proveedores;
drop policy if exists equipacion_proveedores_procurement_manage on public.equipacion_proveedores;
create policy equipacion_proveedores_procurement_manage on public.equipacion_proveedores to authenticated using (private.has_capability('equipment.procurement.manage')) with check (private.has_capability('equipment.procurement.manage'));
drop policy if exists equipacion_pedidos_club_manage on public.equipacion_pedidos;
drop policy if exists equipacion_pedidos_procurement_manage on public.equipacion_pedidos;
create policy equipacion_pedidos_procurement_manage on public.equipacion_pedidos to authenticated using (private.has_capability('equipment.procurement.manage')) with check (private.has_capability('equipment.procurement.manage'));
drop policy if exists equipacion_pedido_lineas_club_manage on public.equipacion_pedido_lineas;
drop policy if exists equipacion_pedido_lineas_procurement_manage on public.equipacion_pedido_lineas;
create policy equipacion_pedido_lineas_procurement_manage on public.equipacion_pedido_lineas to authenticated using (private.has_capability('equipment.procurement.manage')) with check (private.has_capability('equipment.procurement.manage'));
drop policy if exists equipacion_proveedor_temporadas_club_manage on public.equipacion_proveedor_temporadas;
drop policy if exists equipacion_proveedor_temporadas_procurement_manage on public.equipacion_proveedor_temporadas;
create policy equipacion_proveedor_temporadas_procurement_manage on public.equipacion_proveedor_temporadas to authenticated using (private.has_capability('equipment.procurement.manage')) with check (private.has_capability('equipment.procurement.manage'));
drop policy if exists marcas_club_manage on public.marcas;
drop policy if exists marcas_procurement_manage on public.marcas;
create policy marcas_procurement_manage on public.marcas to authenticated using (private.has_capability('equipment.procurement.manage')) with check (private.has_capability('equipment.procurement.manage'));
drop policy if exists equipacion_recepciones_club_manage on public.equipacion_recepciones;
drop policy if exists equipacion_recepciones_stock_manage on public.equipacion_recepciones;
create policy equipacion_recepciones_stock_manage on public.equipacion_recepciones to authenticated using (private.has_capability('equipment.stock.manage')) with check (private.has_capability('equipment.stock.manage'));
drop policy if exists equipacion_recepcion_lineas_club_manage on public.equipacion_recepcion_lineas;
drop policy if exists equipacion_recepcion_lineas_stock_manage on public.equipacion_recepcion_lineas;
create policy equipacion_recepcion_lineas_stock_manage on public.equipacion_recepcion_lineas to authenticated using (private.has_capability('equipment.stock.manage')) with check (private.has_capability('equipment.stock.manage'));

create or replace function private.can_manage_equipacion_tallas(target_persona_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select
    private.has_capability('equipment.manage')
    or target_persona_id = private.current_person_id()
    or exists (
      select 1
      from public.jugadores j
      join public.representaciones_jugador r on r.jugador_id=j.id
      where j.persona_id=target_persona_id
        and r.representante_persona_id=private.current_person_id()
        and r.fecha_desde<=current_date
        and (r.fecha_hasta is null or r.fecha_hasta>=current_date)
    );
$$;;

create or replace function private.equipacion_ajustar_stock(p_temporada uuid,p_articulo uuid,p_talla text,p_delta integer)
returns void language plpgsql security definer set search_path=public,private as $$
declare v_fisica integer; v_res integer;
begin
  if not private.has_capability('equipment.stock.manage') then raise exception 'Not authorized'; end if;
  insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica)
  values(p_temporada,p_articulo,p_talla,greatest(p_delta,0))
  on conflict (temporada_id,articulo_id,talla) do update
    set cantidad_fisica=public.equipacion_stock.cantidad_fisica+p_delta, updated_at=now()
  returning cantidad_fisica,cantidad_reservada into v_fisica,v_res;
  if v_fisica < 0 or v_fisica < v_res then raise exception 'Stock adjustment would invalidate reservations'; end if;
end $$;;

create or replace function private.equipacion_ajustar_stock_lote(
  p_lote uuid,p_ajuste integer,p_motivo text,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare l public.equipacion_stock_lotes%rowtype; aid uuid; actor uuid:=auth.uid(); tid uuid;
begin
  if actor is null or not private.has_capability('equipment.stock.manage') then raise exception 'Not authorized'; end if;
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
end $$;;

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
end $$;;

create or replace function private.equipacion_reservar_asignacion(p_asignacion uuid)
returns void language plpgsql security definer set search_path=public,private as $$
declare arow public.equipacion_asignaciones%rowtype; nrow public.equipacion_necesidades%rowtype; affected integer;
begin
  if not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
  select * into arow from public.equipacion_asignaciones where id=p_asignacion for update;
  if arow.id is null then raise exception 'Assignment not found'; end if;
  if arow.estado='reservada' then return; end if;
  if arow.estado <> 'propuesta' then raise exception 'Only proposed assignments can be reserved'; end if;
  select * into nrow from public.equipacion_necesidades where id=arow.necesidad_id;
  update public.equipacion_stock set cantidad_reservada=cantidad_reservada+arow.cantidad,updated_at=now()
   where temporada_id=nrow.temporada_id and articulo_id=arow.articulo_id and talla=arow.talla
     and cantidad_fisica-cantidad_reservada >= arow.cantidad;
  get diagnostics affected=row_count;
  if affected<>1 then raise exception 'Insufficient available stock'; end if;
  update public.equipacion_asignaciones set estado='reservada',reservado_at=now(),updated_at=now() where id=p_asignacion;
end $$;;

create or replace function private.equipacion_reservar_asignacion_lote(
  p_asignacion uuid,p_lote uuid,p_cantidad integer
) returns uuid language plpgsql security definer set search_path='' as $$
declare a public.equipacion_asignaciones%rowtype; n public.equipacion_necesidades%rowtype;
        l public.equipacion_stock_lotes%rowtype; rid uuid; total integer;
begin
  if not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
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
end $$;;

create or replace function private.equipacion_preparar_asignacion_fifo(p_asignacion uuid)
returns uuid
language plpgsql security definer set search_path='' as $$
declare
  a public.equipacion_asignaciones%rowtype;
  n public.equipacion_necesidades%rowtype;
  ya integer; falta integer; disponible integer; tomar integer;
  l record;
begin
  if not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;

  select * into a from public.equipacion_asignaciones where id=p_asignacion for update;
  if a.id is null then raise exception 'Assignment not found'; end if;
  if a.estado='entregada' then return a.id; end if;
  if a.estado='cancelada' then raise exception 'Cancelled assignment cannot be prepared'; end if;

  select * into n from public.equipacion_necesidades where id=a.necesidad_id;
  if n.id is null or n.confirmada_at is null then raise exception 'Only confirmed equipment requests can be prepared'; end if;

  select coalesce(sum(al.cantidad),0)::integer into ya
  from public.equipacion_asignacion_lotes al
  where al.asignacion_id=a.id and al.estado='reservada';

  if ya>a.cantidad then raise exception 'Existing lot reservations exceed assignment quantity'; end if;
  if ya=a.cantidad then
    update public.equipacion_asignaciones
      set estado='reservada',reservado_at=coalesce(reservado_at,now()),updated_at=now()
    where id=a.id and estado<>'reservada';
    return a.id;
  end if;
  falta:=a.cantidad-ya;

  -- Preflight makes the normal preparation action all-or-nothing for this article.
  select coalesce(sum(l2.cantidad_fisica-l2.cantidad_reservada),0)::integer into disponible
  from public.equipacion_stock_lotes l2
  join public.equipacion_stock_lote_vigencia v on v.lote_id=l2.id
  where v.temporada_id=n.temporada_id and v.estado='valido'
    and l2.articulo_id=a.articulo_id and l2.talla=a.talla
    and l2.cantidad_fisica>l2.cantidad_reservada;

  if disponible<falta then
    raise exception 'Insufficient FIFO stock: available %, required %',disponible,falta;
  end if;

  -- Lock candidates in deterministic FIFO order. Reception-backed lots use the
  -- reception timestamp when available; legacy/manual lots fall back to lot creation.
  for l in
    select l2.id,
           (l2.cantidad_fisica-l2.cantidad_reservada)::integer cantidad_disponible
    from public.equipacion_stock_lotes l2
    join public.equipacion_stock_lote_vigencia v on v.lote_id=l2.id
    left join public.equipacion_recepcion_lineas rl on rl.id=l2.recepcion_linea_id
    left join public.equipacion_recepciones r on r.id=rl.recepcion_id
    where v.temporada_id=n.temporada_id and v.estado='valido'
      and l2.articulo_id=a.articulo_id and l2.talla=a.talla
      and l2.cantidad_fisica>l2.cantidad_reservada
    order by coalesce(r.fecha_recepcion::timestamptz,l2.created_at),l2.created_at,l2.id
    for update of l2
  loop
    exit when falta=0;
    tomar:=least(falta,l.cantidad_disponible);
    perform private.equipacion_reservar_asignacion_lote(a.id,l.id,tomar);
    falta:=falta-tomar;
  end loop;

  if falta<>0 then raise exception 'FIFO reservation became incomplete during preparation'; end if;
  return a.id;
end $$;;

create or replace function private.equipacion_preparar_multiple(
 p_asignaciones uuid[]
) returns table(asignacion_id uuid,preparacion_id uuid)
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid();
 aid uuid;
 pid uuid;
 n_personas integer;
 n_temporadas integer;
 total integer;
 distintos integer;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then
   raise exception 'Not authorized';
 end if;
 if p_asignaciones is null or cardinality(p_asignaciones)=0 then
   raise exception 'At least one assignment must be selected';
 end if;

 select count(*),count(distinct x) into total,distintos from unnest(p_asignaciones) x;
 if total<>distintos then raise exception 'Duplicate assignments are not allowed'; end if;

 -- Lock the complete explicit selection in deterministic order before any reservation.
 perform 1
 from public.equipacion_asignaciones a
 where a.id=any(p_asignaciones)
 order by a.id
 for update;
 if (select count(*) from public.equipacion_asignaciones a where a.id=any(p_asignaciones))<>cardinality(p_asignaciones) then
   raise exception 'One or more selected assignments do not exist';
 end if;

 select count(distinct n.persona_id),count(distinct n.temporada_id)
 into n_personas,n_temporadas
 from public.equipacion_asignaciones a
 join public.equipacion_necesidades n on n.id=a.necesidad_id
 where a.id=any(p_asignaciones);
 if n_personas<>1 or n_temporadas<>1 then
   raise exception 'All selected assignments must belong to the same person and season';
 end if;

 -- One function call is one transaction. 073 performs the real FIFO reservation for each
 -- assignment; any exception rolls back every reservation made earlier in this selection.
 foreach aid in array p_asignaciones loop
   pid:=private.equipacion_preparar_asignacion_fifo(aid);
   asignacion_id:=aid;
   preparacion_id:=pid;
   return next;
 end loop;
end $$;;

create or replace function private.equipacion_materializar_demanda(p_items jsonb)
returns table(asignacion_id uuid,necesidad_id uuid,articulo_id uuid,talla text)
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid();
 elem jsonb; nid uuid; aid uuid; vtalla text; expected integer; existing public.equipacion_asignaciones%rowtype;
 personas integer; temporadas integer;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'At least one demand item must be selected'; end if;

 create temporary table if not exists pg_temp.eq086_items(necesidad_id uuid,articulo_id uuid,talla text,primary key(necesidad_id,articulo_id,talla)) on commit drop;
 truncate pg_temp.eq086_items;
 for elem in select value from jsonb_array_elements(p_items) loop
   begin
     nid:=(elem->>'necesidad_id')::uuid; aid:=(elem->>'articulo_id')::uuid; vtalla:=elem->>'talla';
   exception when others then raise exception 'Invalid demand item payload'; end;
   if nid is null or aid is null or vtalla is null or vtalla='' then raise exception 'Demand item requires necesidad_id, articulo_id and talla'; end if;
   insert into pg_temp.eq086_items values(nid,aid,vtalla) on conflict do nothing;
 end loop;
 if (select count(*) from pg_temp.eq086_items)<>jsonb_array_length(p_items) then raise exception 'Duplicate demand items are not allowed'; end if;

 perform 1 from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id order by n.id for update;
 if (select count(distinct n.persona_id) from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id)<>1
    or (select count(distinct n.temporada_id) from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id)<>1 then
   raise exception 'All selected demand items must belong to the same person and season';
 end if;
 if exists(select 1 from public.equipacion_necesidades n join pg_temp.eq086_items i on i.necesidad_id=n.id where n.confirmada_at is null or n.estado='cancelada') then
   raise exception 'Only confirmed active equipment needs can be materialized';
 end if;
 if exists(
   select 1 from pg_temp.eq086_items i
   left join public.equipacion_demanda_logistica d on d.necesidad_id=i.necesidad_id and d.articulo_id=i.articulo_id and d.talla=i.talla
   where d.necesidad_id is null
 ) then raise exception 'One or more selected items are not current logistical demand'; end if;

 for nid,aid,vtalla,expected in
   select d.necesidad_id,d.articulo_id,d.talla,d.cantidad_demandada
   from public.equipacion_demanda_logistica d join pg_temp.eq086_items i using(necesidad_id,articulo_id,talla)
   order by d.necesidad_id,d.articulo_id,d.talla
 loop
   select * into existing from public.equipacion_asignaciones a
    where a.necesidad_id=nid and a.articulo_id=aid and a.talla=vtalla for update;
   if existing.id is null then
     insert into public.equipacion_asignaciones(necesidad_id,articulo_id,talla,cantidad,estado,origen,asignado_por)
     values(nid,aid,vtalla,expected,'propuesta','automatico',actor)
     returning * into existing;
   elsif existing.estado='cancelada' then
     raise exception 'Cancelled assignment exists for selected demand item';
   elsif existing.cantidad<>expected then
     raise exception 'Existing assignment quantity % does not match current demand %',existing.cantidad,expected;
   end if;
   asignacion_id:=existing.id; necesidad_id:=nid; articulo_id:=aid; talla:=vtalla; return next;
 end loop;
end $$;;

create or replace function private.equipacion_entregar_directo(
 p_asignacion uuid,p_permitir_desplazar boolean default false
) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); a public.equipacion_asignaciones%rowtype;
 n public.equipacion_necesidades%rowtype; reservada integer; falta integer;
 libre integer; fisico integer; tomar integer; l record; x record; liberar integer;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 select * into a from public.equipacion_asignaciones where id=p_asignacion for update;
 if a.id is null then raise exception 'Assignment not found'; end if;
 if a.estado='entregada' then return private.equipacion_confirmar_entrega(a.id,actor); end if;
 if a.estado='cancelada' then raise exception 'Cancelled assignment cannot be delivered'; end if;
 select * into n from public.equipacion_necesidades where id=a.necesidad_id;

 select coalesce(sum(al.cantidad),0)::integer into reservada
 from public.equipacion_asignacion_lotes al
 where al.asignacion_id=a.id and al.estado='reservada';
 if reservada>a.cantidad then raise exception 'Existing reservations exceed assignment quantity'; end if;
 falta:=a.cantidad-reservada;

 if falta>0 then
  select coalesce(sum(sl.cantidad_fisica-sl.cantidad_reservada),0)::integer,
         coalesce(sum(sl.cantidad_fisica),0)::integer
  into libre,fisico
  from public.equipacion_stock_lotes sl
  join public.equipacion_stock_lote_vigencia v on v.lote_id=sl.id
  where v.temporada_id=n.temporada_id and v.estado='valido'
    and sl.articulo_id=a.articulo_id and sl.talla=a.talla;

  if libre<falta and not p_permitir_desplazar then
    raise exception 'Insufficient free stock: available %, required %. Physical stock may be committed to other preparations',libre,falta;
  end if;
  if fisico<falta+reservada then
    raise exception 'Insufficient physical stock: available %, required %',fisico,a.cantidad;
  end if;

  if libre<falta then
   -- Release only as much soft preparation as is necessary. Newest preparation loses priority first.
   for x in
    select al.id al_id,al.asignacion_id,al.lote_id,al.cantidad,al.reservado_at
    from public.equipacion_asignacion_lotes al
    join public.equipacion_asignaciones ax on ax.id=al.asignacion_id
    join public.equipacion_necesidades nx on nx.id=ax.necesidad_id
    where al.estado='reservada' and al.asignacion_id<>a.id
      and ax.articulo_id=a.articulo_id and ax.talla=a.talla and nx.temporada_id=n.temporada_id
    order by al.reservado_at desc,al.id desc
    for update of al
   loop
    exit when libre>=falta;
    liberar:=least(x.cantidad,falta-libre);
    update public.equipacion_stock_lotes
      set cantidad_reservada=cantidad_reservada-liberar,updated_at=now()
      where id=x.lote_id and cantidad_reservada>=liberar;
    if not found then raise exception 'Prepared stock is inconsistent'; end if;

    if liberar=x.cantidad then
      update public.equipacion_asignacion_lotes set estado='liberada',liberado_at=now(),updated_at=now() where id=x.al_id;
    else
      update public.equipacion_asignacion_lotes set cantidad=cantidad-liberar,updated_at=now() where id=x.al_id;
    end if;
    insert into public.equipacion_preparaciones_desplazadas(
      asignacion_afectada_id,asignacion_beneficiaria_id,lote_id,cantidad,desplazada_por)
    values(x.asignacion_id,a.id,x.lote_id,liberar,actor);

    update public.equipacion_asignaciones ax
    set estado=case when coalesce((select sum(z.cantidad) from public.equipacion_asignacion_lotes z
                                  where z.asignacion_id=ax.id and z.estado='reservada'),0)>=ax.cantidad
                    then 'reservada' else 'propuesta' end,
        reservado_at=case when coalesce((select sum(z.cantidad) from public.equipacion_asignacion_lotes z
                                  where z.asignacion_id=ax.id and z.estado='reservada'),0)>=ax.cantidad
                          then ax.reservado_at else null end,
        updated_at=now()
    where ax.id=x.asignacion_id;
    libre:=libre+liberar;
   end loop;
  end if;

  -- Prepare the beneficiary from now-free stock using the established FIFO primitive.
  perform private.equipacion_preparar_asignacion_fifo(a.id);
 end if;

 return private.equipacion_confirmar_entrega(a.id,actor);
end $$;;

create or replace function private.equipacion_entregar_multiple(
 p_asignaciones uuid[],
 p_desplazamiento_autorizado uuid[] default array[]::uuid[]
) returns table(asignacion_id uuid,entrega_id uuid)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); aid uuid; eid uuid; persona uuid; temporada uuid;
 n_personas integer; n_temporadas integer; total integer; distintos integer;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 if p_asignaciones is null or cardinality(p_asignaciones)=0 then raise exception 'At least one assignment must be selected'; end if;

 select count(*),count(distinct x) into total,distintos from unnest(p_asignaciones) x;
 if total<>distintos then raise exception 'Duplicate assignments are not allowed'; end if;
 if exists(select 1 from unnest(p_desplazamiento_autorizado) x where not (x=any(p_asignaciones))) then
   raise exception 'Displacement authorization contains an unselected assignment';
 end if;

 -- Lock all selected assignments in deterministic order before any delivery.
 perform 1 from public.equipacion_asignaciones a
 where a.id=any(p_asignaciones) order by a.id for update;
 if (select count(*) from public.equipacion_asignaciones a where a.id=any(p_asignaciones))<>cardinality(p_asignaciones)
 then raise exception 'One or more selected assignments do not exist'; end if;

 select count(distinct n.persona_id),count(distinct n.temporada_id)
 into n_personas,n_temporadas
 from public.equipacion_asignaciones a join public.equipacion_necesidades n on n.id=a.necesidad_id
 where a.id=any(p_asignaciones);
 if n_personas<>1 or n_temporadas<>1 then
   raise exception 'All selected assignments must belong to the same person and season';
 end if;
 select n.persona_id,n.temporada_id into persona,temporada
 from public.equipacion_asignaciones a
 join public.equipacion_necesidades n on n.id=a.necesidad_id
 where a.id=any(p_asignaciones)
 order by a.id
 limit 1;

 -- PL/pgSQL function execution is one transaction: any exception below rolls back all
 -- deliveries, stock movements, debt snapshots and displaced preparations from this call.
 foreach aid in array p_asignaciones loop
   eid:=private.equipacion_entregar_directo(aid,aid=any(p_desplazamiento_autorizado));
   asignacion_id:=aid; entrega_id:=eid; return next;
 end loop;
end $$;;

create or replace function private.equipacion_confirmar_entrega(p_asignacion uuid,p_usuario uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare a public.equipacion_asignaciones%rowtype; n public.equipacion_necesidades%rowtype; eid uuid;
        al record; total integer; actor uuid:=coalesce(p_usuario,auth.uid()); ce record;
begin
  if not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
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
end $$;;

create or replace function private.equipacion_registrar_devolucion(
 p_entrega uuid,p_cantidad integer,p_reutilizable boolean,p_motivo text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); en public.equipacion_entregas%rowtype; a public.equipacion_asignaciones%rowtype;
 n public.equipacion_necesidades%rowtype; did uuid; prev integer; lid uuid;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 select * into en from public.equipacion_entregas where id=p_entrega for update;
 if en.id is null then raise exception 'Delivery not found'; end if;
 if p_cantidad is null or p_cantidad<=0 then raise exception 'Return quantity must be positive'; end if;
 select coalesce(sum(cantidad),0) into prev from public.equipacion_devoluciones where entrega_id=en.id;
 if prev+p_cantidad>en.cantidad then raise exception 'Return quantity exceeds delivered quantity'; end if;
 select * into a from public.equipacion_asignaciones where id=en.asignacion_id;
 select * into n from public.equipacion_necesidades where id=a.necesidad_id;
 insert into public.equipacion_devoluciones(entrega_id,cantidad,reutilizable,motivo,observaciones,registrada_por)
 values(en.id,p_cantidad,p_reutilizable,p_motivo,p_observaciones,actor) returning id into did;

 if p_reutilizable then
  -- A reusable return becomes a new traceable lot. We do not pretend that the
  -- physical garment can still be identified with the supplier lot it left from.
  insert into public.equipacion_stock_lotes(
    articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,cantidad_fisica,cantidad_reservada)
  values(a.articulo_id,a.talla,n.temporada_id,null,'DEVOLUCION:'||did::text,p_cantidad,0)
  returning id into lid;
  insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,decidido_por,observaciones)
  values(lid,n.temporada_id,'valido',now(),actor,'Prenda reutilizable devuelta por jugador');
  perform private.equipacion_recalcular_stock_legacy(n.temporada_id,a.articulo_id,a.talla);
 end if;
 return did;
end $$;;

create or replace function private.equipacion_crear_necesidad_adicional(
 p_persona uuid,p_temporada uuid,p_articulo uuid,p_cantidad integer default 1,
 p_sin_cargo boolean default false,p_motivo text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); pt public.equipacion_personas_temporada%rowtype;
 n_id uuid; j uuid; e uuid; talla text; v_precio numeric; concepto uuid; cid uuid;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 if p_cantidad is null or p_cantidad<=0 then raise exception 'Quantity must be positive'; end if;
 select * into pt from public.equipacion_personas_temporada
 where persona_id=p_persona and temporada_id=p_temporada and estado='validada'
 order by case when faceta='jugador' then 0 else 1 end limit 1;
 if pt.id is null then raise exception 'Validated season equipment person not found'; end if;
 j:=pt.jugador_id; e:=pt.entrenador_id;
 select case when not a.usa_talla then 'SIN_TALLA' else coalesce(ex.talla,tp.talla_general) end
 into talla
 from public.equipacion_articulos a
 join public.equipacion_tallas_persona tp on tp.persona_id=p_persona and tp.temporada_id=p_temporada and tp.confirmada_at is not null
 left join public.equipacion_tallas_excepcion ex on ex.talla_persona_id=tp.id and ex.articulo_id=a.id
 where a.id=p_articulo and a.activo;
 if talla is null then raise exception 'Confirmed size/article not available'; end if;

 if not p_sin_cargo then
  select ap.precio into v_precio from public.equipacion_articulo_precios_temporada ap
   where ap.temporada_id=p_temporada and ap.articulo_id=p_articulo and ap.activo;
  if v_precio is null then raise exception 'Individual article price is not configured'; end if;
 else v_precio:=0; end if;

 insert into public.equipacion_necesidades(persona_id,temporada_id,faceta,jugador_id,entrenador_id,persona_temporada_id,
   pack_id,articulo_id_adicional,cantidad_adicional,sin_cargo,precio_unitario_snapshot,estado,origen,confirmada_at,comunicada_at)
 values(p_persona,p_temporada,pt.faceta,j,e,pt.id,null,p_articulo,p_cantidad,p_sin_cargo,v_precio,'comunicada','manual',now(),now())
 returning id into n_id;

 insert into public.equipacion_asignaciones(necesidad_id,articulo_id,talla,cantidad,estado,origen,asignado_por)
 values(n_id,p_articulo,talla,p_cantidad,'propuesta','manual',actor);

 if not p_sin_cargo then
  select id into concepto from public.economia_conceptos where codigo='EQUIPACION';
  insert into public.economia_cargos(persona_id,temporada_id,concepto_id,importe_base,descripcion,origen,equipacion_necesidad_id,clave_origen,creado_por)
  values(p_persona,p_temporada,concepto,v_precio*p_cantidad,'Necesidad adicional de equipacion','equipacion',n_id,
    'EQUIPACION_ADICIONAL:'||n_id::text,actor) returning id into cid;
 end if;
 return n_id;
end $$;;

create or replace function private.equipacion_registrar_pago(
 p_necesidad uuid,p_importe numeric,p_metodo text,p_fecha date default current_date,
 p_referencia text default null,p_observaciones text default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); ce record; pid uuid;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 select * into ce from private.equipacion_cargo_estado(p_necesidad);
 if ce.cargo_id is null then raise exception 'Active equipment charge not found for need'; end if;
 if p_importe is null or p_importe<=0 then raise exception 'Payment amount must be positive'; end if;
 if ce.saldo_pendiente<=0 then raise exception 'Equipment charge is already paid'; end if;
 if p_importe>ce.saldo_pendiente then
   raise exception 'Equipment payment exceeds pending balance: maximum %',ce.saldo_pendiente;
 end if;
 pid:=private.economia_registrar_pago(ce.cargo_id,p_importe,p_metodo,p_fecha,p_referencia,p_observaciones);
 return pid;
end $$;;

create or replace function private.equipacion_corregir_solicitud_confirmada(
 p_necesidad uuid,p_talla_general text default null,p_reutiliza_entrenamiento boolean default null,p_motivo text default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare n public.equipacion_necesidades%rowtype; t public.equipacion_tallas_persona%rowtype; actor uuid:=auth.uid();
        old_talla text; old_reuse boolean; cursado boolean; cid uuid;
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 if nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Change reason is required'; end if;
 select * into n from public.equipacion_necesidades where id=p_necesidad for update;
 if n.id is null or n.confirmada_at is null then raise exception 'Confirmed equipment request not found'; end if;
 select * into t from public.equipacion_tallas_persona where persona_id=n.persona_id and temporada_id=n.temporada_id for update;
 if t.id is null or t.confirmada_at is null then raise exception 'Confirmed sizes not found'; end if;
 if exists(select 1 from public.equipacion_asignaciones a join public.equipacion_entregas d on d.asignacion_id=a.id where a.necesidad_id=n.id)
 then raise exception 'Delivered equipment requires a new logistics/economic operation'; end if;

 -- A formal supplier order is historical: correction is allowed but never rewrites it automatically.
 select exists(
   select 1 from public.equipacion_asignaciones a
   join public.equipacion_pedido_lineas pl on pl.articulo_id=a.articulo_id and pl.talla=a.talla
   join public.equipacion_pedidos p on p.id=pl.pedido_id
   where a.necesidad_id=n.id and p.temporada_id=n.temporada_id and p.estado<>'borrador' and p.estado<>'cancelado'
 ) into cursado;

 old_talla:=t.talla_general; old_reuse:=n.reutiliza_entrenamiento;
 if p_talla_general is not null and p_talla_general<>old_talla then
   if p_talla_general not in ('4XS','3XS','2XS','XS','S','M','L','XL','2XL','3XL') then raise exception 'Invalid size'; end if;
   update public.equipacion_tallas_persona set talla_general=p_talla_general,updated_at=now() where id=t.id;
   insert into public.equipacion_solicitud_cambios(necesidad_id,persona_id,temporada_id,campo,valor_anterior,valor_nuevo,motivo,pedido_cursado,cambiado_por)
   values(n.id,n.persona_id,n.temporada_id,'talla_general',to_jsonb(old_talla),to_jsonb(p_talla_general),trim(p_motivo),cursado,actor);
 end if;
 if p_reutiliza_entrenamiento is not null and p_reutiliza_entrenamiento is distinct from old_reuse then
   update public.equipacion_necesidades set reutiliza_entrenamiento=p_reutiliza_entrenamiento,updated_at=now() where id=n.id;
   insert into public.equipacion_solicitud_cambios(necesidad_id,persona_id,temporada_id,campo,valor_anterior,valor_nuevo,motivo,pedido_cursado,cambiado_por)
   values(n.id,n.persona_id,n.temporada_id,'reutiliza_entrenamiento',to_jsonb(old_reuse),to_jsonb(p_reutiliza_entrenamiento),trim(p_motivo),cursado,actor);
 end if;
 cid:=private.equipacion_recalcular_cargo(n.id);
 return cid;
end $$;;

create or replace function private.equipacion_proponer_dorsal(p_temporada uuid,p_equipo uuid,p_jugador uuid,p_es_portero boolean default false)
returns integer language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); d integer; candidates integer[];
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 select dorsal into d from public.equipacion_dorsales
  where temporada_id=p_temporada and equipo_id=p_equipo and jugador_id=p_jugador;
 if d is not null then return d; end if;
 candidates:=case when p_es_portero then array[1,13,25] else array[2,3,4,5,6,7,8,9,10,11,12,14,15,16,17,18,19,20,21,22,23,24,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99] end;
 select x into d from unnest(candidates) x
 where not exists(select 1 from public.equipacion_dorsales e
                  where e.temporada_id=p_temporada and e.equipo_id=p_equipo and e.dorsal=x)
 limit 1;
 if d is null then raise exception 'No dorsal available for team'; end if;
 insert into public.equipacion_dorsales(temporada_id,equipo_id,jugador_id,dorsal,es_portero,origen,asignado_por)
 values(p_temporada,p_equipo,p_jugador,d,p_es_portero,'automatico',actor);
 return d;
end $$;;

create or replace function private.equipacion_cambiar_dorsal_propuesto(p_temporada uuid,p_equipo uuid,p_jugador uuid,p_dorsal integer)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not private.has_capability('equipment.fulfillment.manage') then raise exception 'Not authorized'; end if;
 if exists(select 1 from public.equipacion_pedido_lineas pl join public.equipacion_pedidos p on p.id=pl.pedido_id
           where p.temporada_id=p_temporada and pl.jugador_id=p_jugador and pl.dorsal is not null and p.estado<>'borrador' and p.estado<>'cancelado')
 then raise exception 'Dorsal cannot change after personalized order is placed'; end if;
 insert into public.equipacion_dorsales(temporada_id,equipo_id,jugador_id,dorsal,origen,asignado_por)
 values(p_temporada,p_equipo,p_jugador,p_dorsal,'manual',actor)
 on conflict(temporada_id,equipo_id,jugador_id) do update
 set dorsal=excluded.dorsal,origen='manual',asignado_por=actor,asignado_at=now(),updated_at=now();
end $$;;

create or replace function private.equipacion_validar_necesidad_confirmada()
returns trigger language plpgsql set search_path=public,private as $$
declare v_estado text;
begin
 if new.persona_temporada_id is null then
   if new.confirmada_at is not null then raise exception 'Confirmed equipment need requires validated season person'; end if;
   return new;
 end if;
 select estado into v_estado from public.equipacion_personas_temporada
 where id=new.persona_temporada_id and persona_id=new.persona_id and temporada_id=new.temporada_id and faceta=new.faceta;
 if v_estado is distinct from 'validada' then raise exception 'Equipment need requires a club-validated person for the season'; end if;
 if new.confirmada_at is not null and not exists(
   select 1 from public.equipacion_tallas_persona t
   where t.persona_id=new.persona_id and t.temporada_id=new.temporada_id and t.confirmada_at is not null
 ) then raise exception 'Confirmed equipment need requires confirmed sizes'; end if;
 return new;
end $$;;

create or replace function public.equipacion_guardar_pedido_borrador(
  p_temporada_id uuid,p_proveedor_id uuid,p_lineas jsonb,p_pedido_id uuid default null,
  p_numero text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path to '' as $$
declare
  v_actor uuid:=auth.uid(); v_id uuid; v_proveedor public.equipacion_proveedores%rowtype;
  v_row jsonb; v_art uuid; v_talla text; v_cantidad integer; v_precio numeric;
  v_jugador uuid; v_dorsal integer; v_origen text; v_personalizable boolean; v_count integer:=0;
begin
  if v_actor is null or not private.has_capability('equipment.procurement.manage') then raise exception 'Not authorized'; end if;
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
end $$;;

create or replace function public.equipacion_cursar_pedido(p_pedido_id uuid)
returns uuid language plpgsql security definer set search_path to '' as $$
declare v_actor uuid:=auth.uid(); v_pedido public.equipacion_pedidos%rowtype; v_lineas integer;
begin
  if v_actor is null or not private.has_capability('equipment.procurement.manage') then raise exception 'Not authorized'; end if;
  select * into v_pedido from public.equipacion_pedidos where id=p_pedido_id for update;
  if v_pedido.id is null then raise exception 'Order not found'; end if;
  if v_pedido.estado<>'borrador' then raise exception 'Only draft orders can be placed'; end if;
  if v_pedido.proveedor_id is null then raise exception 'Structured supplier is required before placing order'; end if;
  select count(*) into v_lineas from public.equipacion_pedido_lineas where pedido_id=p_pedido_id;
  if v_lineas=0 then raise exception 'Order has no lines'; end if;
  update public.equipacion_pedido_lineas set updated_at=updated_at where pedido_id=p_pedido_id;
  update public.equipacion_pedidos set estado='pedido',fecha_pedido=current_date,updated_at=now() where id=p_pedido_id;
  return p_pedido_id;
end $$;;

create or replace function public.equipacion_registrar_recepcion_pedido(
  p_pedido_id uuid,p_lineas jsonb,p_fecha_recepcion date default current_date,
  p_referencia text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path to '' as $$
declare v_actor uuid:=auth.uid(); v_recepcion uuid; v_row jsonb; v_linea uuid;
        v_recibida integer; v_aceptada integer; v_obs text; v_pos integer:=0;
begin
  if v_actor is null or not private.has_capability('equipment.stock.manage') then raise exception 'Not authorized'; end if;
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
end $$;;

create or replace function public.equipacion_registrar_stock_existente(
  p_articulo_id uuid,p_talla text,p_cantidad integer,p_temporada_origen_id uuid,p_temporada_vigencia_id uuid,
  p_proveedor_id uuid default null,p_marca_id uuid default null,p_vigencia text default 'valido',
  p_referencia text default null,p_observaciones text default null
) returns uuid language plpgsql security definer set search_path to '' as $$
declare v_actor uuid:=auth.uid(); v_lote uuid; v_proveedor_nombre text;
begin
  if v_actor is null or not private.has_capability('equipment.stock.manage') then raise exception 'Not authorized'; end if;
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
end $$;;

commit;
