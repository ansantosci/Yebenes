-- 064 - Fix traceable-lot creation from accepted reception lines.
begin;

create or replace function private.equipacion_crear_lote_recepcion()
returns trigger language plpgsql security definer set search_path='' as $$
declare pe public.equipacion_pedidos%rowtype; pl public.equipacion_pedido_lineas%rowtype;
        r public.equipacion_recepciones%rowtype; lid uuid;
begin
  if new.cantidad_aceptada<=0 then return new; end if;
  select * into r from public.equipacion_recepciones where id=new.recepcion_id;
  select * into pl from public.equipacion_pedido_lineas where id=new.pedido_linea_id;
  select * into pe from public.equipacion_pedidos where id=pl.pedido_id;

  insert into public.equipacion_stock_lotes(
    articulo_id,talla,temporada_origen_id,proveedor_nombre,referencia_proveedor,
    cantidad_fisica,cantidad_reservada,recepcion_linea_id)
  values(
    pl.articulo_id,pl.talla,pe.temporada_id,pe.proveedor_nombre,coalesce(r.referencia,pe.numero),
    new.cantidad_aceptada,0,new.id)
  on conflict(recepcion_linea_id) where recepcion_linea_id is not null
  do nothing
  returning id into lid;

  if lid is not null then
    insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado,decidido_at,observaciones)
    values(lid,pe.temporada_id,'valido',now(),'Vigencia automatica de temporada origen')
    on conflict(lote_id,temporada_id) do nothing;
    perform private.equipacion_recalcular_stock_legacy(pe.temporada_id,pl.articulo_id,pl.talla);
  end if;
  return new;
end $$;

-- Preserve 063 hardening after CREATE OR REPLACE.
revoke all on function private.equipacion_crear_lote_recepcion() from public,anon,authenticated;
grant execute on function private.equipacion_crear_lote_recepcion() to service_role;

commit;
