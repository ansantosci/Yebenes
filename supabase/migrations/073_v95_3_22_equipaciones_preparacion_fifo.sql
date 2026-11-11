-- 073 - Automatic logical FIFO preparation per equipment assignment/article.
-- Pack remains the visible operational unit; individual articles can be prepared/delivered independently.
begin;

create or replace function private.equipacion_preparar_asignacion_fifo(p_asignacion uuid)
returns uuid
language plpgsql security definer set search_path='' as $$
declare
  a public.equipacion_asignaciones%rowtype;
  n public.equipacion_necesidades%rowtype;
  ya integer; falta integer; disponible integer; tomar integer;
  l record;
begin
  if not private.has_any_role(array['administrador','club']) then raise exception 'Not authorized'; end if;

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
end $$;

-- Pack-level status is derived from its article assignments. Partial preparation and
-- partial delivery are first-class normal states.
create or replace view public.equipacion_reparto_resumen as
select n.id necesidad_id,n.persona_id,n.temporada_id,n.faceta,n.jugador_id,n.entrenador_id,n.pack_id,
count(a.id)::integer prendas_asignadas,
count(a.id) filter(where a.estado='reservada')::integer prendas_preparadas,
count(a.id) filter(where a.estado='entregada')::integer prendas_entregadas,
case
 when count(a.id)=0 then 'pendiente'
 when count(a.id) filter(where a.estado='entregada')=count(a.id) then 'completo'
 when count(a.id) filter(where a.estado='entregada')>0 then 'entrega_parcial'
 when count(a.id) filter(where a.estado='reservada')=count(a.id) then 'preparado'
 when count(a.id) filter(where a.estado='reservada')>0 then 'preparacion_parcial'
 else 'pendiente' end estado_reparto
from public.equipacion_necesidades n
left join public.equipacion_asignaciones a on a.necesidad_id=n.id and a.estado<>'cancelada'
group by n.id,n.persona_id,n.temporada_id,n.faceta,n.jugador_id,n.entrenador_id,n.pack_id;

revoke all on function private.equipacion_preparar_asignacion_fifo(uuid) from public,anon;
grant execute on function private.equipacion_preparar_asignacion_fifo(uuid) to authenticated,service_role;
grant select on public.equipacion_reparto_resumen to authenticated,service_role;
revoke all on public.equipacion_reparto_resumen from anon;

commit;
