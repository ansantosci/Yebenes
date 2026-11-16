-- 091_fix_090_rls_initplan_contract.sql
-- Corrective migration after 090 was already applied/registered in TEST.
-- No functional DDL is required: PostgreSQL correctly normalized
-- (select auth.uid()) as ( SELECT auth.uid() AS uid ) in pg_policies.qual.
-- The correction is exclusively in the regression contract shipped with 091.

do $$
begin
  -- Intentionally no-op. Keep 090 immutable.
  null;
end $$;
