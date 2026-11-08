-- Contract 059: security parity for Equipaciones objects introduced by 056-058.
do $$
declare
  missing_rls integer;
  missing_policy integer;
begin
  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema='public'
      and table_name in (
        'equipacion_personas_temporada',
        'equipacion_stock_lotes',
        'equipacion_stock_lote_vigencia',
        'equipacion_stock_lotes_disponibles',
        'equipacion_reparto_resumen'
      )
      and grantee='anon'
  ) then
    raise exception '059 security contract failed: anon has Equipaciones grants';
  end if;

  select count(*) into missing_rls
  from (values
    ('equipacion_personas_temporada'),
    ('equipacion_stock_lotes'),
    ('equipacion_stock_lote_vigencia')
  ) v(name)
  where not exists (
    select 1 from pg_tables t
    where t.schemaname='public' and t.tablename=v.name and t.rowsecurity
  );
  if missing_rls <> 0 then
    raise exception '059 security contract failed: % new tables without RLS',missing_rls;
  end if;

  select count(*) into missing_policy
  from (values
    ('equipacion_personas_temporada','equipacion_personas_temporada_club_manage'),
    ('equipacion_stock_lotes','equipacion_stock_lotes_club_manage'),
    ('equipacion_stock_lote_vigencia','equipacion_stock_lote_vigencia_club_manage')
  ) v(tablename,policyname)
  where not exists (
    select 1 from pg_policies p
    where p.schemaname='public'
      and p.tablename=v.tablename
      and p.policyname=v.policyname
  );
  if missing_policy <> 0 then
    raise exception '059 security contract failed: % club policies missing',missing_policy;
  end if;

  if has_function_privilege('anon','private.equipacion_validar_necesidad_confirmada()','EXECUTE')
     or has_function_privilege('authenticated','private.equipacion_validar_necesidad_confirmada()','EXECUTE') then
    raise exception '059 security contract failed: validation trigger helper exposed';
  end if;
end $$;

select '059_equipaciones_security_hardening_contract' as contract,'PASS' as result;
