# Supabase contract tests

`supabase/tests/contracts/` contains post-migration database contracts.

Rules:
- Contract files are read-only checks. They must not mutate application data or schema.
- A contract must fail with a PostgreSQL exception when an invariant is broken.
- `Deploy Supabase migrations` runs every `*.sql` contract after migrations and before reporting the registry.
- Any failed contract makes the deployment job fail.
- Add or extend a contract whenever a migration introduces a durable database/API/security invariant.

Initial contracts:
- `001_migration_registry_contract.sql`: validates the migration registry infrastructure.
- `044_contacto_menor_contract.sql`: validates the RPC signature, `SECURITY DEFINER`, and EXECUTE privileges introduced by migration 044.
