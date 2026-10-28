# Yebenes release pipeline

`Promote Yebenes release` coordinates the normal release path:

1. database migrations and post-migration contract tests;
2. Supabase Edge Functions;
3. GitHub Pages multi-environment frontend;
4. HTTP smoke tests against the route represented by the selected source branch.

## Guardrails

- TEST accepts `develop` or `test`.
- DEMO accepts only `main` and requires `DEPLOY_DEMO`.
- Individual workflows remain manually runnable for diagnosis/recovery. The orchestrator is the normal promotion path.
- Cron and datasets are intentionally outside the release pipeline. Seeds/test datasets are not promoted to DEMO.

## Required secrets

Existing: `SUPABASE_TEST_DB_URL`, `SUPABASE_DEMO_DB_URL`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_TEST_PROJECT_REF`.
For DEMO Edge Function promotion the repository must also have `SUPABASE_DEMO_PROJECT_REF`. The access token used by CI must have permission to deploy Edge Functions to the selected target project.

## Important

This pipeline coordinates deployment; it does not merge branches. Git promotion remains `develop -> test -> main`.
