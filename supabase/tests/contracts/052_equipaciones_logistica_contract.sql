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

-- Authorization smoke: the API must remain closed without an authenticated club/admin context.
do $$
declare sample_id uuid;
begin
  select id into sample_id from public.equipacion_asignaciones limit 1;
  if sample_id is null then return; end if;
  perform set_config('request.jwt.claim.sub','',true);
  begin
    perform private.equipacion_reservar_asignacion(sample_id);
    raise exception '052 authorization smoke failed: unauthenticated reserve was allowed';
  exception when others then
    if sqlerrm='052 authorization smoke failed: unauthenticated reserve was allowed' then raise; end if;
    if sqlerrm<>'Not authorized' then raise exception '052 authorization smoke failed: unexpected rejection: %',sqlerrm; end if;
  end;
end $$;

-- Transactional smoke: fully isolated person/player -> validated season -> size -> need -> stock -> reserve -> deliver.
begin;
do $$
declare
  tid uuid; aid uuid; packid uuid;
  personid uuid := '05200000-0000-4000-8000-000000000010'::uuid;
  playerid uuid := '05200000-0000-4000-8000-000000000011'::uuid;
  ptid uuid := '05200000-0000-4000-8000-000000000012'::uuid;
  sizeid uuid := '05200000-0000-4000-8000-000000000013'::uuid;
  nid uuid := '05200000-0000-4000-8000-000000000014'::uuid;
  asid uuid := '05200000-0000-4000-8000-000000000015'::uuid;
  test_auth_uid uuid;
begin
  select p.auth_user_id into test_auth_uid
  from public.personas p
  join public.persona_roles pr on pr.persona_id=p.id and pr.activo
    and pr.fecha_desde<=current_date and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
  join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
  where p.activo and p.auth_user_id is not null
  order by (r.codigo='administrador') desc limit 1;
  if test_auth_uid is null then raise exception '052 contract setup failed: no authenticated admin/club identity'; end if;
  perform set_config('request.jwt.claim.sub',test_auth_uid::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);

  select id into tid from public.temporadas where estado='activa' order by created_at desc nulls last limit 1;
  select p.id,p.pack_id,pa.articulo_id into nid,packid,aid
  from public.equipacion_necesidades p
  join public.equipacion_pack_articulos pa on pa.pack_id=p.pack_id
  where p.pack_id is not null limit 1;
  if tid is null or packid is null or aid is null then raise exception '052 contract setup failed: season/pack/article context missing'; end if;
  -- nid above is context only; reset to the contract-owned need id.
  nid := '05200000-0000-4000-8000-000000000014'::uuid;

  insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,email_contacto,telefono,activo)
  values(personid,'Contrato 052','Logistica',date '1990-01-01','contract052@test.invalid','699052052',true);
  insert into public.jugadores(id,persona_id,activo,fecha_alta)
  values(playerid,personid,true,current_date);

  insert into public.equipacion_personas_temporada(id,persona_id,temporada_id,faceta,jugador_id,estado,validada_at)
  values(ptid,personid,tid,'jugador',playerid,'validada',now());
  insert into public.equipacion_tallas_persona(id,temporada_id,persona_id,talla_general,confirmada_at)
  values(sizeid,tid,personid,'3XS',now());
  insert into public.equipacion_necesidades
    (id,temporada_id,persona_id,faceta,jugador_id,pack_id,estado,comunicada_at,confirmada_at,persona_temporada_id)
  values(nid,tid,personid,'jugador',playerid,packid,'comunicada',now(),now(),ptid);

  insert into public.equipacion_stock(temporada_id,articulo_id,talla,cantidad_fisica,cantidad_reservada)
  values(tid,aid,'3XS',2,0)
  on conflict(temporada_id,articulo_id,talla) do update
  set cantidad_fisica=greatest(public.equipacion_stock.cantidad_fisica,2),cantidad_reservada=0;
  insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado,origen)
  values(asid,nid,aid,'3XS',1,'propuesta','manual');

  perform private.equipacion_reservar_asignacion(asid);
  if not exists(select 1 from public.equipacion_asignaciones where id=asid and estado='reservada') then raise exception '052 smoke failed: reserve state'; end if;
  if not exists(select 1 from public.equipacion_stock where temporada_id=tid and articulo_id=aid and talla='3XS' and cantidad_reservada=1) then raise exception '052 smoke failed: stock reservation'; end if;

  perform private.equipacion_confirmar_entrega(asid,null);
  if not exists(select 1 from public.equipacion_asignaciones where id=asid and estado='entregada') then raise exception '052 smoke failed: delivery state'; end if;
  if (select count(*) from public.equipacion_entregas where asignacion_id=asid)<>1 then raise exception '052 smoke failed: expected one delivery'; end if;
end $$;
rollback;

select '052_equipaciones_logistica_contract' as contract,'PASS' as result;
