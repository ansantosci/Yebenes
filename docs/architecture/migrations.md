# Supabase migrations workflow

Managed migrations start at `044_*.sql`. Files 001-043 are historical baseline and are never executed or registered by this workflow.

Workflow: `.github/workflows/supabase-migrations-deploy.yml`

## TEST
Run manually with `source_ref=develop` (or `test`) and `target=TEST`. The workflow uses `SUPABASE_TEST_DB_URL`.

## DEMO
Run manually only after the migration has reached `main`, with `source_ref=main`, `target=DEMO`, and `demo_confirmation=DEPLOY_DEMO`. The workflow uses `SUPABASE_DEMO_DB_URL`.

For every managed migration the workflow calculates SHA-256. If a migration is already registered with the same hash it is skipped. If the same filename has a different hash, deployment aborts.

Registry: `private.schema_migrations`. It is bootstrapped automatically. Application roles receive no access to the registry.
