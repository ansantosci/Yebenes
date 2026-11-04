-- Contract for Equipaciones phase 2 logistics.
do $$
declare missing integer;
begin
  select count(*) into missing from (values
    ('equipacion_stock'),('equipacion_pedidos'),('equipacion_pedido_lineas'),('equipacion_recepciones'),
    ('equipacion_recepcion_lineas'),('equipacion_asignaciones'),('equipacion_entregas'),('equipacion_traspasos_stock')
  ) v(name) where to_regclass('public.'||v.name) is null;
  if missing<>0 then raise exception '052 contract failed: % logistics tables missing',missing; end if;

  if to_regclass('public.equipacion_demanda_logistica') is null or to_regclass('public.equipacion_compra_sugerida') is null then
    raise exception '052 contract failed: derived demand/purchase views missing';
  end if;
  if to_regprocedure('private.equipacion_ajustar_stock(uuid,uuid,text,integer)') is null then raise exception '052 contract failed: stock function missing'; end if;
  if to_regprocedure('private.equipacion_reservar_asignacion(uuid)') is null then raise exception '052 contract failed: reserve function missing'; end if;
  if to_regprocedure('private.equipacion_confirmar_entrega(uuid,uuid)') is null then raise exception '052 contract failed: delivery function missing'; end if;

  if exists (select 1 from information_schema.role_table_grants where table_schema='public' and table_name like 'equipacion_%' and grantee='anon') then
    raise exception '052 contract failed: anon must not have equipacion table grants';
  end if;
  if (select count(*) from pg_tables where schemaname='public' and tablename in
    ('equipacion_stock','equipacion_pedidos','equipacion_pedido_lineas','equipacion_recepciones','equipacion_recepcion_lineas','equipacion_asignaciones','equipacion_entregas','equipacion_traspasos_stock') and rowsecurity) <> 8 then
    raise exception '052 contract failed: RLS not enabled on all logistics tables';
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.equipacion_stock'::regclass and contype='u') then
    raise exception '052 contract failed: stock uniqueness missing';
  end if;
end $$;

-- Transactional smoke: stock -> reserve -> deliver, fully rolled back.
begin;
do $$
declare
  tid uuid; aid uuid; nid uuid; asid uuid; sid uuid; before_count integer; after_count integer;
begin
  select n.temporada_id,n.id into tid,nid from public.equipacion_necesidades n where n.estado<>'cancelada' limit 1;
  if nid is null then return; end if;
  select pa.articulo_id into aid from public.equipacion_necesidades n join public.equipacion_pack_articulos pa on pa.pack_id=n.pack_id where n.id=nid limit 1;
  if aid is null then return; end if;
  insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica) values(tid,aid,'3XS',2)
    on conflict(temporada_id,articulo_id,talla) do update set cantidad_fisica=greatest(public.equipacion_stock.cantidad_fisica,2),cantidad_reservada=0;
  insert into public.equipacion_asignaciones(necesidad_id,articulo_id,talla,cantidad,estado,origen) values(nid,aid,'3XS',1,'propuesta','manual')
    on conflict(necesidad_id,articulo_id,talla) do update set estado='propuesta',cantidad=1
    returning id into asid;
  perform private.equipacion_reservar_asignacion(asid);
  if not exists(select 1 from public.equipacion_stock where temporada_id=tid and articulo_id=aid and talla='3XS' and cantidad_reservada=1) then raise exception '052 smoke failed: reserve'; end if;
  perform private.equipacion_confirmar_entrega(asid,null);
  if not exists(select 1 from public.equipacion_asignaciones where id=asid and estado='entregada') then raise exception '052 smoke failed: delivery'; end if;
end $$;
rollback;

select '052_equipaciones_logistica_contract' as contract,'PASS' as result;
