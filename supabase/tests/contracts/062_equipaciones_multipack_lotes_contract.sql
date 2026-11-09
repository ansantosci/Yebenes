-- Contract 062: multipack + traceable lot logistics, dataset independent.
do $$
begin
  if not exists(select 1 from information_schema.tables where table_schema='public' and table_name='equipacion_asignacion_lotes')
     or not exists(select 1 from information_schema.tables where table_schema='public' and table_name='equipacion_ajustes_stock')
     or not exists(select 1 from information_schema.tables where table_schema='public' and table_name='equipacion_proveedores')
     or not exists(select 1 from information_schema.views where table_schema='public' and table_name='equipacion_material_persona') then
    raise exception '062 contract failed: logistics objects missing';
  end if;
  if exists(select 1 from information_schema.role_table_grants
            where table_schema='public' and table_name in ('equipacion_asignacion_lotes','equipacion_ajustes_stock','equipacion_proveedores')
              and grantee='anon') then
    raise exception '062 contract failed: anon grants found';
  end if;
  if has_function_privilege('anon','private.equipacion_ajustar_stock_lote(uuid,integer,text,text)','EXECUTE')
     or has_function_privilege('anon','private.equipacion_reservar_asignacion_lote(uuid,uuid,integer)','EXECUTE') then
    raise exception '062 contract failed: logistics RPC exposed to anon';
  end if;
end $$;

begin;
do $$
declare
  tid uuid:='06200000-0000-4000-8000-000000000001';
  pid uuid:='06200000-0000-4000-8000-000000000002';
  jid uuid:='06200000-0000-4000-8000-000000000003';
  art uuid:='06200000-0000-4000-8000-000000000004';
  p1 uuid:='06200000-0000-4000-8000-000000000005';
  p2 uuid:='06200000-0000-4000-8000-000000000006';
  n1 uuid:='06200000-0000-4000-8000-000000000007';
  n2 uuid:='06200000-0000-4000-8000-000000000008';
  asg uuid:='06200000-0000-4000-8000-000000000009';
  l1 uuid:='06200000-0000-4000-8000-000000000010';
  l2 uuid:='06200000-0000-4000-8000-000000000011';
begin
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(tid,'2098/2099 CONTRACT 062',2098,2099,date '2098-07-01',date '2099-06-30','planificacion');
  insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo)
  values(pid,'Persona','Contract 062',date '1990-01-01',true);
  insert into public.jugadores(id,persona_id,activo,fecha_alta) values(jid,pid,true,date '2098-07-01');
  insert into public.equipacion_articulos(id,nombre,codigo,tipo_prenda,ambito,variante,usa_talla,activo)
  values(art,'Camiseta 062','CONTRACT-062','camiseta','jugador','general',true,true);
  insert into public.equipacion_packs(id,temporada_id,codigo,nombre,destinatario,modalidad,precio) values
  (p1,tid,'TRAIN-062','Entrenamiento 062','jugador','entrenamiento',100),
  (p2,tid,'MATCH-062','Partido 062','jugador','partido_campo',35);

  insert into public.equipacion_necesidades(id,persona_id,temporada_id,faceta,jugador_id,pack_id,estado)
  values(n1,pid,tid,'jugador',jid,p1,'validada'),(n2,pid,tid,'jugador',jid,p2,'validada');
  if (select count(*) from public.equipacion_necesidades where persona_id=pid and temporada_id=tid)<>2 then
    raise exception '062 contract failed: multipack needs not supported';
  end if;
  begin
    insert into public.equipacion_necesidades(persona_id,temporada_id,faceta,jugador_id,pack_id,estado)
    values(pid,tid,'jugador',jid,p1,'validada');
    raise exception '062 contract failed: duplicate same-pack need accepted';
  exception when unique_violation then null; end;

  insert into public.equipacion_asignaciones(id,necesidad_id,articulo_id,talla,cantidad,estado)
  values(asg,n1,art,'L',3,'propuesta');
  insert into public.equipacion_stock_lotes(id,articulo_id,talla,temporada_origen_id,referencia_proveedor,cantidad_fisica,cantidad_reservada) values
  (l1,art,'L',tid,'CONTRACT-LOT-A',2,2),(l2,art,'L',tid,'CONTRACT-LOT-B',1,1);
  insert into public.equipacion_stock_lote_vigencia(lote_id,temporada_id,estado)
  values(l1,tid,'valido'),(l2,tid,'valido');
  insert into public.equipacion_asignacion_lotes(asignacion_id,lote_id,cantidad,estado)
  values(asg,l1,2,'reservada'),(asg,l2,1,'reservada');
  update public.equipacion_asignaciones set estado='reservada',reservado_at=now() where id=asg;
  if (select sum(cantidad) from public.equipacion_asignacion_lotes where asignacion_id=asg and estado='reservada')<>3 then
    raise exception '062 contract failed: multi-lot assignment unsupported';
  end if;

  -- The reason requirement is a schema invariant; avoid depending on auth.users test identities.
  if not exists(
    select 1 from pg_constraint c
    join pg_class r on r.oid=c.conrelid
    join pg_namespace nsp on nsp.oid=r.relnamespace
    where nsp.nspname='public' and r.relname='equipacion_ajustes_stock'
      and c.contype='c' and pg_get_constraintdef(c.oid) ilike '%motivo%'
  ) then
    raise exception '062 contract failed: adjustment reason constraint missing';
  end if;
end $$;
rollback;

select '062_equipaciones_multipack_lotes_contract' as contract,'PASS' as result;
