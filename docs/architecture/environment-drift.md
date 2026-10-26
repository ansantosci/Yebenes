# Environment drift check (ARCH-06)

`Compare environment state` is a read-only GitHub Actions workflow. It never applies migrations, deploys functions, writes data, or changes Pages.

It compares each environment against its intended repository ref:

- TEST normally against `develop`.
- DEMO normally against `main`.

For PostgreSQL migrations it reads `private.schema_migrations` and classifies the database as:

- `ALIGNED`: every managed migration expected by the ref is present with the same SHA-256 and there are no unexpected managed migrations.
- `BEHIND`: expected migrations are missing, or the migration registry has not yet been introduced in that environment.
- `DRIFT`: an applied filename has a different SHA-256, or the database contains managed migrations not present in the expected ref.
- `ERROR`: the environment could not be inspected.

For the frontend it reads the public `version.json` and compares it with the expected ref.

Edge Function source hashes are recorded from Git, but this check deliberately reports them as `NOT_DIRECTLY_VERIFIABLE`: the deployed Supabase source hash is not exposed by the interfaces used here. The release manifest is the deployment evidence for Edge Functions. This distinction prevents the drift report from claiming a verification it did not perform.

The workflow produces `environment-drift-report.json` as an artifact and in the GitHub Actions summary. `BEHIND` and `DRIFT` are diagnostic results and do not modify or automatically repair an environment.
