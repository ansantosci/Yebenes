# ARCH-04 fix — TEST support infrastructure

The first architecture guardrail correctly detected legacy DDL inside `supabase/seed`. This patch fixes the repository rather than weakening the rule.

- `supabase/seed/**` remains fixture/data-only.
- TEST-only schema helpers move to `supabase/test-support/00-test-infrastructure.sql`.
- TEST bootstrap/dataset workflows execute test-support before seeds.
- `supabase/test-support` is forbidden from defining `public.*` application schema objects; those belong to baseline/migrations.
- The former seed infrastructure file remains as a no-DDL compatibility tombstone and can be deleted later in a normal Git cleanup.
