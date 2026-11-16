-- 091_rls_auth_initialization_plan_contract.sql
-- Corrects the textual assertion from contract 090.
-- PostgreSQL deparses (select auth.uid()) as ( SELECT auth.uid() AS uid ).

do $$
declare
  r record;
  expr text;
  stripped text;
  expected_count integer;
begin
  -- RLS remains enabled on all five affected tables.
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname in (
        'entrenador_disponibilidad',
        'entrenador_formaciones',
        'entrenador_licencias_rffm',
        'entrenador_temporadas',
        'horarios_equipo'
      )
  loop
    if not (
      select c.relrowsecurity
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=r.relname
    ) then
      raise exception '091: RLS disabled on public.%', r.relname;
    end if;
  end loop;

  -- Exact policy surface remains six authenticated permissive SELECT policies.
  select count(*) into expected_count
  from pg_policies p
  where p.schemaname='public'
    and (p.tablename,p.policyname) in (
      ('entrenador_disponibilidad','entrenador_disponibilidad_read_v90_1'),
      ('entrenador_disponibilidad','entrenador_disponibilidad_self_read'),
      ('entrenador_formaciones','entrenador_formaciones_read'),
      ('entrenador_licencias_rffm','entrenador_licencias_read'),
      ('entrenador_temporadas','entrenador_temporadas_self_read'),
      ('horarios_equipo','horarios_equipo_coach_read')
    )
    and p.cmd='SELECT'
    and p.permissive='PERMISSIVE'
    and p.roles=array['authenticated']::name[];

  if expected_count <> 6 then
    raise exception '091: expected 6 authenticated SELECT policies, found %', expected_count;
  end if;

  for r in
    select p.tablename,p.policyname,p.qual
    from pg_policies p
    where p.schemaname='public'
      and (p.tablename,p.policyname) in (
        ('entrenador_disponibilidad','entrenador_disponibilidad_read_v90_1'),
        ('entrenador_disponibilidad','entrenador_disponibilidad_self_read'),
        ('entrenador_formaciones','entrenador_formaciones_read'),
        ('entrenador_licencias_rffm','entrenador_licencias_read'),
        ('entrenador_temporadas','entrenador_temporadas_self_read'),
        ('horarios_equipo','horarios_equipo_coach_read')
      )
  loop
    expr := lower(coalesce(r.qual,''));

    -- Accept PostgreSQL's canonical deparse:
    -- ( SELECT auth.uid() AS uid )
    if expr !~ '\(\s*select\s+auth\.uid\s*\(\s*\)(\s+as\s+uid)?\s*\)' then
      raise exception '091: %.% does not contain InitPlan-wrapped auth.uid(): %',
        r.tablename,r.policyname,r.qual;
    end if;

    -- Strip every valid wrapped occurrence. Any remaining auth.uid()
    -- would be a per-row direct call and therefore a regression.
    stripped := regexp_replace(
      expr,
      '\(\s*select\s+auth\.uid\s*\(\s*\)(\s+as\s+uid)?\s*\)',
      '',
      'g'
    );

    if stripped ~ 'auth\.uid\s*\(\s*\)' then
      raise exception '091: %.% still contains direct auth.uid(): %',
        r.tablename,r.policyname,r.qual;
    end if;
  end loop;

  -- Existing write/club policies remain present with their original role/command shape.
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='entrenador_formaciones'
      and policyname='entrenador_formaciones_write'
      and cmd='ALL' and roles=array['authenticated']::name[]
  ) then raise exception '091: entrenador_formaciones_write missing/changed'; end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='entrenador_licencias_rffm'
      and policyname='entrenador_licencias_write'
      and cmd='ALL' and roles=array['authenticated']::name[]
  ) then raise exception '091: entrenador_licencias_write missing/changed'; end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='entrenador_temporadas'
      and policyname='entrenador_temporadas_club'
      and cmd='ALL' and roles=array['authenticated']::name[]
  ) then raise exception '091: entrenador_temporadas_club missing/changed'; end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='horarios_equipo'
      and policyname='horarios_equipo_club'
      and cmd='ALL' and roles=array['authenticated']::name[]
  ) then raise exception '091: horarios_equipo_club missing/changed'; end if;
end $$;

select 'rls_auth_initialization_plan_contract_v2' contract, 'PASS' result;
