-- Contract 061: season lifecycle schema/security plus dataset-independent structural invariants.
do $$
declare
  states text[];
begin
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='temporadas' and column_name='en_cierre_at')
     or not exists(select 1 from information_schema.tables where table_schema='public' and table_name='historico_estados_temporada') then
    raise exception '061 contract failed: lifecycle objects missing';
  end if;
  if not exists(select 1 from pg_indexes where schemaname='public' and indexname='temporadas_unica_activa_uq') then
    raise exception '061 contract failed: unique active season index missing';
  end if;
  if not exists(select 1 from pg_tables where schemaname='public' and tablename='historico_estados_temporada' and rowsecurity) then
    raise exception '061 contract failed: history RLS missing';
  end if;
  if exists(select 1 from information_schema.role_table_grants
            where table_schema='public' and table_name='historico_estados_temporada' and grantee='anon') then
    raise exception '061 contract failed: anon history grants';
  end if;
  if has_function_privilege('anon','public.activar_temporada(uuid)','EXECUTE')
     or has_function_privilege('anon','public.cerrar_temporada(uuid,text)','EXECUTE')
     or has_function_privilege('authenticated','private.temporada_registrar_cambio(uuid,text,text,text,uuid)','EXECUTE') then
    raise exception '061 contract failed: lifecycle function exposure';
  end if;
end $$;

-- Structural transaction test. RPC authorization is intentionally exercised by application/auth tests;
-- here we prove state values, uniqueness and history table accept the intended lifecycle.
begin;
do $$
declare
  a uuid:='06100000-0000-4000-8000-000000000001';
  b uuid:='06100000-0000-4000-8000-000000000002';
begin
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado,activada_at)
  values(a,'2097/2098 CONTRACT 061',2097,2098,date '2097-07-01',date '2098-06-30','en_cierre',now());
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(b,'2098/2099 CONTRACT 061',2098,2099,date '2098-07-01',date '2099-06-30','planificacion');

  update public.temporadas set estado='cerrada',cerrada_at=now() where id=a;
  insert into public.historico_estados_temporada(temporada_id,estado_anterior,estado_nuevo,motivo)
  values(a,'en_cierre','cerrada','Contract 061');

  if (select estado from public.temporadas where id=a)<>'cerrada' then
    raise exception '061 contract failed: close state unsupported';
  end if;
  if not exists(select 1 from public.historico_estados_temporada where temporada_id=a and estado_nuevo='cerrada') then
    raise exception '061 contract failed: lifecycle history unsupported';
  end if;

  begin
    update public.temporadas set estado='INVALIDO' where id=b;
    raise exception '061 contract failed: invalid state accepted';
  exception when check_violation then null; end;
end $$;
rollback;

select '061_temporadas_ciclo_contract' as contract,'PASS' as result;
