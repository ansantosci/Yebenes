-- Contract 095 - catalogo de tallajes y metadatos comerciales de articulos.
begin;

do $$
declare c integer; ropa uuid; balon uuid; sin_talla uuid; art_ropa uuid:='09500000-0000-4000-8000-000000000001';
        art_bal uuid:='09500000-0000-4000-8000-000000000002'; art_restr uuid:='09500000-0000-4000-8000-000000000003';
        talla_s uuid; talla_m uuid; talla_l uuid; talla_xl uuid; talla4 uuid;
begin
  select id into ropa from public.equipacion_sistemas_tallaje where codigo='ROPA';
  select id into balon from public.equipacion_sistemas_tallaje where codigo='BALON';
  select id into sin_talla from public.equipacion_sistemas_tallaje where codigo='SIN_TALLA';
  if ropa is null or balon is null or sin_talla is null then raise exception '095: structural sizing systems missing'; end if;

  select count(*) into c from public.equipacion_tallaje_valores tv join public.equipacion_sistemas_tallaje s on s.id=tv.sistema_tallaje_id where s.codigo='ROPA';
  if c<>10 then raise exception '095: ROPA values=% expected 10',c; end if;
  select count(*) into c from public.equipacion_tallaje_valores tv join public.equipacion_sistemas_tallaje s on s.id=tv.sistema_tallaje_id where s.codigo='BALON';
  if c<>3 then raise exception '095: BALON values=% expected 3',c; end if;

  if exists(select 1 from public.equipacion_articulos where sistema_tallaje_id is null) then raise exception '095: article without sizing system after backfill'; end if;

  -- Legacy insert without sistema_tallaje_id remains compatible and maps usa_talla=true to ROPA.
  insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo,modelo,referencia_fabricante)
  values(art_ropa,'Camiseta Contract 095','ART-095-ROPA','camiseta','jugador','general',true,true,'Training 2095','FAB-095');
  if (select sistema_tallaje_id from public.equipacion_articulos where id=art_ropa)<>ropa then raise exception '095: legacy sized article not mapped to ROPA'; end if;
  if not private.equipacion_articulo_admite_talla(art_ropa,'M') then raise exception '095: unrestricted ROPA article rejected M'; end if;

  -- Catalog may describe future ball articles without enabling legacy equipment stock/order checks yet.
  insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo,sistema_tallaje_id,modelo)
  values(art_bal,'Balon Contract 095','ART-095-BAL','material','jugador','general',true,true,balon,'Ball 2095');
  if not private.equipacion_articulo_admite_talla(art_bal,'4') then raise exception '095: BALON article rejected 4'; end if;
  if private.equipacion_articulo_admite_talla(art_bal,'M') then raise exception '095: BALON article accepted textile M'; end if;

  -- Specific rows restrict the otherwise complete system.
  insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo,sistema_tallaje_id)
  values(art_restr,'Camiseta restringida 095','ART-095-REST','camiseta','jugador','general',true,true,ropa);
  select id into talla_s from public.equipacion_tallaje_valores where sistema_tallaje_id=ropa and codigo='S';
  select id into talla_m from public.equipacion_tallaje_valores where sistema_tallaje_id=ropa and codigo='M';
  select id into talla_l from public.equipacion_tallaje_valores where sistema_tallaje_id=ropa and codigo='L';
  select id into talla_xl from public.equipacion_tallaje_valores where sistema_tallaje_id=ropa and codigo='XL';
  select id into talla4 from public.equipacion_tallaje_valores where sistema_tallaje_id=balon and codigo='4';
  insert into public.equipacion_articulo_tallas(articulo_id,talla_id) values(art_restr,talla_s),(art_restr,talla_m),(art_restr,talla_l);
  if not private.equipacion_articulo_admite_talla(art_restr,'M') then raise exception '095: restricted article rejected configured M'; end if;
  if private.equipacion_articulo_admite_talla(art_restr,'XL') then raise exception '095: restricted article accepted unconfigured XL'; end if;

  begin
    insert into public.equipacion_articulo_tallas(articulo_id,talla_id) values(art_restr,talla4);
    raise exception '095: cross-system article size accepted';
  exception when others then
    if sqlerrm='095: cross-system article size accepted' then raise; end if;
  end;

  begin
    update public.equipacion_articulos set sistema_tallaje_id=balon where id=art_restr;
    raise exception '095: incompatible system change accepted';
  exception when others then
    if sqlerrm='095: incompatible system change accepted' then raise; end if;
  end;
end $$;

-- Security/ACL: no anon, no client execution of private helpers.
do $$
declare c integer;
begin
  select count(*) into c from pg_class x join pg_namespace n on n.oid=x.relnamespace
  where n.nspname='public' and x.relname in ('equipacion_sistemas_tallaje','equipacion_tallaje_valores','equipacion_articulo_tallas') and x.relrowsecurity;
  if c<>3 then raise exception '095: RLS missing on new tables'; end if;
  if has_table_privilege('anon','public.equipacion_sistemas_tallaje','SELECT')
     or has_table_privilege('anon','public.equipacion_tallaje_valores','SELECT')
     or has_table_privilege('anon','public.equipacion_articulo_tallas','SELECT') then raise exception '095: anon table access'; end if;
  if has_function_privilege('authenticated','private.equipacion_articulo_admite_talla(uuid,text)','EXECUTE')
     or has_function_privilege('anon','private.equipacion_articulo_admite_talla(uuid,text)','EXECUTE') then raise exception '095: private validation helper exposed'; end if;
end $$;

rollback;
select '095_catalogo_tallajes_articulos_contract' contract,'PASS' result;
