-- Contract: migration registry infrastructure required by the deployment workflow.
do $$
declare
  missing_columns text;
begin
  if to_regclass('private.schema_migrations') is null then
    raise exception 'CONTRACT FAIL: private.schema_migrations does not exist';
  end if;

  select string_agg(required.column_name, ', ' order by required.column_name)
    into missing_columns
  from (values
    ('filename'),('sha256'),('applied_at'),('source_ref'),('target_environment'),('run_id')
  ) as required(column_name)
  where not exists (
    select 1
    from information_schema.columns c
    where c.table_schema='private'
      and c.table_name='schema_migrations'
      and c.column_name=required.column_name
  );

  if missing_columns is not null then
    raise exception 'CONTRACT FAIL: private.schema_migrations missing columns: %', missing_columns;
  end if;

  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid=c.conrelid
    join pg_namespace n on n.oid=t.relnamespace
    where n.nspname='private'
      and t.relname='schema_migrations'
      and c.contype='p'
  ) then
    raise exception 'CONTRACT FAIL: private.schema_migrations has no primary key';
  end if;
end
$$;

select 'migration_registry_contract' as contract, 'PASS' as result;
