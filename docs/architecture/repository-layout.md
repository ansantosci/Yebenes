# Yebenes repository architecture contract

Git is the source of truth for application code and database evolution. Each area has one responsibility:

| Area | Responsibility | Must not contain |
|---|---|---|
| `supabase/baseline/` | immutable pre-044 PostgreSQL structural snapshot + manifest | environment data, later migrations |
| `supabase/migrations/` | ordered immutable DB evolution (`044+`) | test fixtures, secrets |
| `supabase/tests/contracts/` | post-migration structural/security assertions | product data or schema evolution |
| `supabase/seed/` | environment fixtures/master/test data | schema/security DDL |
| `supabase/functions/` | Edge Functions | embedded credentials |
| `supabase/config/` | versionable non-secret configuration metadata | secret values |
| `scripts/` | CI/bootstrap/validation utilities | credentials |
| root frontend | browser application and public environment selection | privileged keys |

## Release order

`architecture guardrails -> migrations -> contract tests -> Edge Functions -> frontend -> smoke tests`

For a brand-new environment:

`baseline -> migrations 044..N -> contracts -> environment configuration -> Edge Functions -> approved seed -> frontend -> smoke tests`

DEMO schema export is diagnostic/recovery material, not the source for constructing a new environment.

## Immutable database rule

Never edit a migration already applied to an environment. Fixes are new numbered migrations. The baseline is also immutable: changing it requires an explicit baseline-versioning decision, not an incidental edit.

## Secrets rule

No secret value is committed to Git. Database credentials, `service_role`, deployment tokens, CRON secrets, mail passwords/tokens and private keys remain in GitHub/Supabase secret stores. Public browser configuration is not treated as a privileged secret.

## Automated enforcement

`Validate repository architecture` runs `scripts/validate-architecture.py`. The coordinated release pipeline invokes the same guardrail before touching a target environment. A structural responsibility violation or likely committed credential blocks the release.
