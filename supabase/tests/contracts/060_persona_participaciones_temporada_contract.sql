-- Contract 060: common person/season/facet participation is additive, secure and dataset-independent.
do $$
declare
  rls_missing integer;
begin
  if not exists(select 1 from information_schema.tables where table_schema='public' and table_name='persona_participaciones_temporada')
     or not exists(select 1 from information_schema.tables where table_schema='public' and table_name='historico_participaciones_temporada') then
    raise exception '060 contract failed: participation tables missing';
  end if;
  select count(*) into rls_missing from (values('persona_participaciones_temporada'),('historico_participaciones_temporada')) v(n)
  where not exists(select 1 from pg_tables t where t.schemaname='public' and t.tablename=v.n and t.rowsecurity);
  if rls_missing<>0 then raise exception '060 contract failed: RLS missing'; end if;
  if exists(select 1 from information_schema.role_table_grants
            where table_schema='public' and table_name in ('persona_participaciones_temporada','historico_participaciones_temporada')
              and grantee='anon') then
    raise exception '060 contract failed: anon grants found';
  end if;
  if has_function_privilege('authenticated','private.validar_faceta_participacion_temporada()','EXECUTE')
     or has_function_privilege('authenticated','private.registrar_historico_participacion_temporada()','EXECUTE') then
    raise exception '060 contract failed: trigger helper exposed';
  end if;
end $$;

begin;
do $$
declare
  tid uuid:='06000000-0000-4000-8000-000000000001';
  carlos uuid:='06000000-0000-4000-8000-000000000010';
  pablo uuid:='06000000-0000-4000-8000-000000000020';
  lucia uuid:='06000000-0000-4000-8000-000000000030';
  cj uuid:='06000000-0000-4000-8000-000000000011';
  ce uuid:='06000000-0000-4000-8000-000000000012';
  pj uuid:='06000000-0000-4000-8000-000000000021';
  pe uuid:='06000000-0000-4000-8000-000000000022';
  lj uuid:='06000000-0000-4000-8000-000000000031';
  n integer;
begin
  insert into public.temporadas(id,nombre,anio_inicio,anio_fin,fecha_inicio,fecha_fin,estado)
  values(tid,'2098/2099 CONTRACT 060',2098,2099,date '2098-07-01',date '2099-06-30','planificacion');

  insert into public.personas(id,nombre,primer_apellido,fecha_nacimiento,activo) values
  (carlos,'Carlos','Contract 060',date '1985-01-01',true),
  (pablo,'Pablo','Contract 060',date '2008-01-01',true),
  (lucia,'Lucia','Contract 060',date '2010-01-01',true);

  insert into public.jugadores(id,persona_id,activo,fecha_alta) values
  (cj,carlos,true,date '2098-07-01'),(pj,pablo,true,date '2098-07-01'),(lj,lucia,true,date '2098-07-01');
  insert into public.entrenadores(id,persona_id,activo) values
  (ce,carlos,true),(pe,pablo,true);

  insert into public.representaciones_jugador(jugador_id,representante_persona_id,fecha_desde,motivo_alta)
  values(pj,carlos,date '2098-07-01','Contract 060'),(lj,carlos,date '2098-07-01','Contract 060');

  insert into public.persona_participaciones_temporada(persona_id,temporada_id,faceta,origen,estado,solicitada_at,aceptada_at) values
  (carlos,tid,'jugador','continuidad','solicitada',now(),null),
  (carlos,tid,'entrenador','continuidad','aceptada',now(),now()),
  (pablo,tid,'jugador','continuidad','aceptada',now(),now()),
  (pablo,tid,'entrenador','continuidad','en_revision',now(),null),
  (lucia,tid,'jugador','continuidad','aceptada',now(),now());

  select count(*) into n from public.persona_participaciones_temporada where temporada_id=tid;
  if n<>5 then raise exception '060 contract failed: expected 5 multifacet participations, got %',n; end if;

  if exists(select 1 from public.persona_participaciones_temporada where temporada_id=tid and faceta not in ('jugador','entrenador')) then
    raise exception '060 contract failed: unexpected tutor participation';
  end if;

  if (select count(*) from public.historico_participaciones_temporada h
      join public.persona_participaciones_temporada p on p.id=h.participacion_id where p.temporada_id=tid)<>5 then
    raise exception '060 contract failed: initial history missing';
  end if;

  begin
    insert into public.persona_participaciones_temporada(persona_id,temporada_id,faceta,origen,estado)
    values(carlos,tid,'jugador','administrativa','propuesta');
    raise exception '060 contract failed: duplicate participation accepted';
  exception when unique_violation then null; end;

  begin
    insert into public.persona_participaciones_temporada(persona_id,temporada_id,faceta,origen,estado)
    values(carlos,tid,'tutor','administrativa','propuesta');
    raise exception '060 contract failed: tutor facet accepted';
  exception when check_violation then null; end;

  begin
    insert into public.persona_participaciones_temporada(persona_id,temporada_id,faceta,origen,estado)
    values('06000000-0000-4000-8000-000000000099',tid,'jugador','administrativa','propuesta');
    raise exception '060 contract failed: missing person/facet accepted';
  exception when foreign_key_violation then null; end;
end $$;
rollback;

select '060_persona_participaciones_temporada_contract' as contract,'PASS' as result;
