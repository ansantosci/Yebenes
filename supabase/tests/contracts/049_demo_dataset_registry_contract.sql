-- Contract: DEMO synthetic-data registry remains private and deterministic.
do $$
begin
  if to_regclass('private.demo_datasets') is null
     or to_regclass('private.demo_dataset_entities') is null then
    raise exception 'CONTRACT FAIL: DEMO dataset registry tables are missing';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname = 'demo_uuid'
      and pg_get_function_identity_arguments(p.oid) = 'p_key text'
  ) then
    raise exception 'CONTRACT FAIL: private.demo_uuid(text) is missing';
  end if;

  if has_table_privilege('anon', 'private.demo_datasets', 'select')
     or has_table_privilege('authenticated', 'private.demo_datasets', 'select')
     or has_table_privilege('anon', 'private.demo_dataset_entities', 'select')
     or has_table_privilege('authenticated', 'private.demo_dataset_entities', 'select')
     or has_function_privilege('anon', 'private.demo_uuid(text)', 'execute')
     or has_function_privilege('authenticated', 'private.demo_uuid(text)', 'execute') then
    raise exception 'CONTRACT FAIL: DEMO dataset registry is exposed to application roles';
  end if;
end
$$;

select 'demo_dataset_registry_contract' as contract, 'PASS' as result;
