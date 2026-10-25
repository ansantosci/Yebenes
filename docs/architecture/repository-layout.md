# Repository architecture

## Source-of-truth boundaries

- `supabase/baseline/`: immutable reproducible database baseline.
- `supabase/migrations/`: ordered application migrations (044+). Never edit an applied migration.
- `supabase/tests/contracts/`: post-migration database contract tests.
- `supabase/seed/`: data and fixtures only; no schema/security DDL.
- `supabase/test-support/`: TEST-only support infrastructure. It may create test-support objects but must not create application objects in `public`.
- `supabase/functions/`: Supabase Edge Functions.
- `supabase/config/`: versionable, non-secret configuration documentation/configuration.
- `.github/workflows/`: deployment/orchestration workflows.
- `scripts/`: repository validation and automation helpers.

Secrets must remain in GitHub/Supabase secret stores and must never be committed.

The stable release path is guarded in this order: repository architecture -> migrations -> contract tests -> Edge Functions -> frontend -> smoke tests.
