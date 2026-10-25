# Reproducible Supabase baseline (ARCH-03)

## Source of truth
`supabase/baseline/000_pre_044_schema.sql` is the immutable structural baseline immediately before migration 044. It contains the versioned `public` + `private` PostgreSQL schema and no operational/test data.

The baseline is pinned by `supabase/baseline/manifest.json` with SHA-256 and `migration_floor: 44`.

## Reconstruction rule
A new database is reconstructed as:

1. Create a fresh Supabase project and configure platform-level items from the runbook (Auth, Storage, secrets, Vault/Cron as applicable).
2. Apply `supabase/baseline/000_pre_044_schema.sql` with `ON_ERROR_STOP=1`.
3. Apply every immutable file in `supabase/migrations/` with numeric prefix >= 044, in numeric order.
4. Run every SQL contract in `supabase/tests/contracts/`.
5. Deploy Edge Functions.
6. Load only the seed appropriate to the target environment.
7. Run smoke tests.

DEMO is no longer the normal source used to construct another environment. Schema export from DEMO is retained only for drift diagnostics, disaster recovery evidence and comparison.

## Immutability
Never edit the baseline after it is adopted. Any structural change after the baseline is a numbered migration. Never fold 044+ back into this baseline.

## Validation
`Validate reproducible Supabase baseline` verifies the pinned SHA-256, migration floor and that migration 044 content has not leaked into the baseline.

## Important boundary
The PostgreSQL baseline does not recreate Supabase platform configuration by itself: Auth settings/users, Storage bucket metadata, secrets, Vault, Cron and external provider configuration remain runbook/configuration concerns until explicitly automated.
