-- 094_proveedores_pedidos_recepciones_operativa_contract.sql
-- Structural/security + deterministic regression for V96.4.0 backend.

do $$
declare fn oid; src text; cnt integer;
begin
  if to_regclass('public.equipacion_proveedores') is null or to_regclass('public.marcas') is null
     or to_regclass('public.equipacion_proveedor_temporadas') is null then raise exception '094: provider/brand foundation missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='equipacion_pedidos' and column_name='proveedor_id') then raise exception '094: structured supplier missing on orders'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='equipacion_articulos' and column_name='marca_id') then raise exception '094: brand missing on articles'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='equipacion_stock_lotes' and column_name='proveedor_id')
     or not exists(select 1 from information_schema.columns where table_schema='public' and table_name='equipacion_stock_lotes' and column_name='marca_id') then raise exception '094: lot provenance missing'; end if;
  if not (select relrowsecurity from pg_class where oid='public.marcas'::regclass)
     or not (select relrowsecurity from pg_class where oid='public.equipacion_proveedor_temporadas'::regclass) then raise exception '094: RLS missing'; end if;
  if has_table_privilege('anon','public.marcas','SELECT') or has_table_privilege('anon','public.equipacion_proveedor_temporadas','SELECT') then raise exception '094: new master data exposed to anon'; end if;
  foreach fn in array array[
    'public.equipacion_guardar_pedido_borrador(uuid,uuid,jsonb,uuid,text,text)'::regprocedure::oid,
    'public.equipacion_cursar_pedido(uuid)'::regprocedure::oid,
    'public.equipacion_registrar_recepcion_pedido(uuid,jsonb,date,text,text)'::regprocedure::oid,
    'public.equipacion_registrar_stock_existente(uuid,text,integer,uuid,uuid,uuid,uuid,text,text,text)'::regprocedure::oid
  ] loop
    if has_function_privilege('anon',fn,'EXECUTE') then raise exception '094: public RPC exposed to anon'; end if;
    if not has_function_privilege('authenticated',fn,'EXECUTE') then raise exception '094: authenticated cannot execute RPC'; end if;
    select pg_get_functiondef(fn) into src;
    if position('SECURITY DEFINER' in src)=0 then raise exception '094: RPC is not SECURITY DEFINER'; end if;
    if not exists(select 1 from pg_proc p where p.oid=fn and coalesce(array_to_string(p.proconfig,','),'') like '%search_path=%') then raise exception '094: RPC search_path not fixed'; end if;
    if position('private.has_any_role' in src)=0 then raise exception '094: RPC lacks Club/Admin authorization'; end if;
  end loop;
  if has_function_privilege('anon','private.equipacion_crear_lote_recepcion()','EXECUTE')
     or has_function_privilege('authenticated','private.equipacion_crear_lote_recepcion()','EXECUTE')
     or has_function_privilege('anon','private.equipacion_aplicar_recepcion_linea_lote_personalizado()','EXECUTE')
     or has_function_privilege('authenticated','private.equipacion_aplicar_recepcion_linea_lote_personalizado()','EXECUTE') then
    raise exception '094: internal lot triggers directly executable by clients'; end if;
  select count(*) into cnt from pg_indexes where schemaname='public' and indexname='equipacion_pedido_lineas_personalizada_uq' and indexdef ilike '%jugador_id%';
  if cnt<>1 then raise exception '094: personalized uniqueness is not player-scoped'; end if;
end $$;

-- Full isolated smoke using an existing authenticated Club/Admin identity, never TEST-S helpers.
begin;
do $$
declare
  tid uuid:='09400000-0000-4000-8000-000000000001'; tid_old uuid:='09400000-0000-4000-8000-000000000031'; p1 uuid:='09400000-0000-4000-8000-000000000002';
  p2 uuid:='09400000-0000-4000-8000-000000000003'; j1 uuid:='09400000-0000-4000-8000-000000000004';
  j2 uuid:='09400000-0000-4000-8000-000000000005'; cat uuid:='09400000-0000-4000-8000-000000000006';
  e1 uuid:='09400000-0000-4000-8000-000000000007'; e2 uuid:='09400000-0000-4000-8000-000000000008';
  artp uuid:='09400000-0000-4000-8000-000000000009'; artn uuid:='09400000-0000-4000-8000-000000000019';
  prov uuid:='09400000-0000-4000-8000-000000000011'; prov_old uuid:='09400000-0000-4000-8000-000000000021';
  marca uuid:='09400000-0000-4000-8000-000000000012'; marca_old uuid:='09400000-0000-4000-8000-000000000022';
  ped uuid; l1 uuid; l2 uuid; rec uuid; lot uuid; actor uuid; c integer; eco_cargos_before bigint; eco_pagos_before bigint;
begin
  select p.auth_user_id into actor from public.personas p
  join public.persona_roles pr on pr.persona_id=p.id and pr.activo and pr.fecha_desde<=current_date and (pr.fecha_hasta is null or pr.fecha_hasta>=current_date)
  join public.roles r on r.id=pr.rol_id and r.codigo in ('administrador','club')
  where p.activo and p.auth_user_id is not null order by (r.codigo='administrador') desc limit 1;
  if actor is null then raise exception '094 setup: no authenticated admin/club identity'; end if;
  select count(*) into eco_cargos_before from public.economia_cargos;
  select count(*) into eco_pagos_before from public.economia_pagos;
  perform set_config('request.jwt.claim.sub',actor::text,true); perform set_config('request.jwt.claim.role','authenticated',true);

  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(tid,'2094/2095 CONTRACT 094',2094,2095,date '2094-07-01',date '2095-06-30','planificacion');
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(tid_old,'2093/2094 CONTRACT 094',2093,2094,date '2093-07-01',date '2094-06-30','cerrada');
  insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo) values
  (p1,'Jugador','Contract094A',date '2000-01-01',true),(p2,'Jugador','Contract094B',date '2000-01-02',true);
  insert into public.jugadores(id,persona_id,activo,fecha_alta) values(j1,p1,true,current_date),(j2,p2,true,current_date);
  insert into public.categorias(id,codigo,nombre,orden,activo) values(cat,'C094','Categoria 094',94,true);
  insert into public.reglas_categoria_temporada(temporada_id,categoria_id,activo) values(tid,cat,true);
  insert into public.equipos(id,temporada_id,categoria_id,nombre,codigo,activo) values(e1,tid,cat,'Equipo 094 A','E094A',true),(e2,tid,cat,'Equipo 094 B','E094B',true);
  insert into public.equipacion_proveedores(id,nombre,activo,integracion_tipo) values(prov,'Proveedor Contract 094',true,'manual'),(prov_old,'Proveedor Historico 094',false,'manual');
  insert into public.marcas(id,nombre,activo) values(marca,'Marca Contract 094',true),(marca_old,'Marca Historica 094',false);
  insert into public.equipacion_proveedor_temporadas(proveedor_id,temporada_id,ambito,principal,activo) values(prov,tid,'equipaciones',true,true);
  insert into public.equipacion_articulos(id,codigo,nombre,tipo_prenda,usa_talla,activo,personalizable_dorsal,marca_id) values
  (artp,'ART-094-P','Camiseta personalizada 094','camiseta',true,true,true,marca),
  (artn,'ART-094-N','Pantalon normal 094','pantalon',true,true,false,marca);
  insert into public.equipacion_dorsales(temporada_id,equipo_id,jugador_id,dorsal,origen) values(tid,e1,j1,8,'manual'),(tid,e2,j2,8,'manual');

  -- Same article+size+dorsal for different players is valid in one order.
  ped:=public.equipacion_guardar_pedido_borrador(tid,prov,jsonb_build_array(
    jsonb_build_object('articulo_id',artp,'talla','L','cantidad',1,'jugador_id',j1,'dorsal',8,'origen','manual'),
    jsonb_build_object('articulo_id',artp,'talla','L','cantidad',1,'jugador_id',j2,'dorsal',8,'origen','manual'),
    jsonb_build_object('articulo_id',artn,'talla','L','cantidad',3,'origen','manual')
  ),null,'C094-001','Contrato 094');
  select count(*) into c from public.equipacion_pedido_lineas where pedido_id=ped;
  if c<>3 then raise exception '094: draft did not preserve three lines'; end if;
  select id into l1 from public.equipacion_pedido_lineas where pedido_id=ped and jugador_id=j1;
  select id into l2 from public.equipacion_pedido_lineas where pedido_id=ped and jugador_id=j2;
  perform public.equipacion_cursar_pedido(ped);
  begin
    perform public.equipacion_guardar_pedido_borrador(tid,prov,'[]'::jsonb,ped,null,null);
    raise exception '094: placed order was editable';
  exception when others then if sqlerrm='094: placed order was editable' then raise; end if; end;
  rec:=public.equipacion_registrar_recepcion_pedido(ped,jsonb_build_array(
    jsonb_build_object('pedido_linea_id',l1,'cantidad_recibida',1,'cantidad_aceptada',1),
    jsonb_build_object('pedido_linea_id',l2,'cantidad_recibida',1,'cantidad_aceptada',0,'observaciones','Incidencia')
  ),current_date,'C094-R1','Parcial');
  select count(*) into c from public.equipacion_stock_lotes where recepcion_linea_id in (select id from public.equipacion_recepcion_lineas where recepcion_id=rec);
  if c<>1 then raise exception '094: accepted personalized reception created % lots, expected 1',c; end if;
  if not exists(select 1 from public.equipacion_stock_lotes where recepcion_linea_id in (select id from public.equipacion_recepcion_lineas where recepcion_id=rec)
                and proveedor_id=prov and marca_id=marca and jugador_origen_id=j1 and dorsal=8) then raise exception '094: personalized lot lost provenance'; end if;

  -- Historical inactive provider/brand are valid for stock already owned by the Club.
  lot:=public.equipacion_registrar_stock_existente(artn,'L',4,tid_old,tid,prov_old,marca_old,'no_valido','INV-C094','Stock historico');
  if not exists(select 1 from public.equipacion_stock_lotes where id=lot and proveedor_id=prov_old and marca_id=marca_old and temporada_origen_id=tid_old and cantidad_fisica=4) then raise exception '094: historical stock lot missing'; end if;
  if not exists(select 1 from public.equipacion_stock_lote_vigencia where lote_id=lot and temporada_id=tid and estado='no_valido') then raise exception '094: historical stock validity missing'; end if;
  if not exists(select 1 from public.equipacion_movimientos_stock where articulo_id=artn and tipo='inventario_inicial' and cantidad=4 and referencia='INV-C094') then raise exception '094: initial inventory movement missing'; end if;
  if (select count(*) from public.economia_cargos)<>eco_cargos_before or (select count(*) from public.economia_pagos)<>eco_pagos_before then
    raise exception '094: physical order/reception/inventory operations altered Economy';
  end if;
end $$;
rollback;
select '094_proveedores_pedidos_recepciones_operativa_contract' contract,'PASS' result;
