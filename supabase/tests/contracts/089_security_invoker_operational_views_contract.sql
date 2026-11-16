-- 089_security_invoker_operational_views_contract.sql
do $$
declare
  r record;
  v_options text;
begin
  -- All nine Advisor-reported views must exist and be SECURITY INVOKER.
  for r in
    select x.view_name
    from (values
      ('equipacion_compra_sugerida'),
      ('equipacion_demanda_logistica'),
      ('equipacion_stock_lotes_disponibles'),
      ('equipacion_stock_resumen'),
      ('equipacion_estado_operativo'),
      ('equipacion_material_persona'),
      ('equipacion_reparto_resumen'),
      ('economia_estado_cargos'),
      ('economia_cuenta_persona_temporada')
    ) as x(view_name)
  loop
    if to_regclass('public.' || r.view_name) is null then
      raise exception '089: required view public.% is missing', r.view_name;
    end if;

    select coalesce(array_to_string(c.reloptions, ','), '')
      into v_options
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = r.view_name
      and c.relkind = 'v';

    if position('security_invoker=true' in v_options) = 0 then
      raise exception '089: public.% is not security_invoker=true (options=%)',
        r.view_name, coalesce(v_options,'<NULL>');
    end if;

    if not has_table_privilege('authenticated', 'public.' || r.view_name, 'SELECT') then
      raise exception '089: authenticated lost SELECT on public.%', r.view_name;
    end if;

    if has_table_privilege('anon', 'public.' || r.view_name, 'SELECT') then
      raise exception '089: anon unexpectedly has SELECT on public.%', r.view_name;
    end if;
  end loop;

  -- Economic views must continue to be protected by RLS on every ledger table.
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname in (
        'economia_cargos',
        'economia_ajustes',
        'economia_pagos',
        'economia_devoluciones'
      )
  loop
    if not (
      select c.relrowsecurity
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=r.relname
    ) then
      raise exception '089: RLS disabled on public.%', r.relname;
    end if;

    if not exists (
      select 1 from pg_policies p
      where p.schemaname='public'
        and p.tablename=r.relname
        and 'authenticated'=any(p.roles)
    ) then
      raise exception '089: no authenticated RLS policy on public.%', r.relname;
    end if;
  end loop;

  -- 088 boundary remains in force.
  if has_table_privilege('anon','public.economia_estado_cargos','SELECT')
     or has_table_privilege('anon','public.economia_cuenta_persona_temporada','SELECT') then
    raise exception '089: regression of 088 economic-view anon boundary';
  end if;

  if to_regclass('public.entrenadores_persona_id_uniq') is not null then
    raise exception '089: regression of 088 duplicate-index removal';
  end if;
end $$;

select 'security_invoker_operational_views_contract' contract, 'PASS' result;
