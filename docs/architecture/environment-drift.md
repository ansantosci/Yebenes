# Environment drift check (ARCH-06 v2)

The project has three Git/Pages environments and two Supabase backends:

- **DEVELOP**: `develop` branch, Pages `/develop/`. No independent Supabase database in the current topology.
- **TEST**: `test` branch, Pages `/test/`, Supabase TEST.
- **DEMO**: `main` branch, root Pages URL, Supabase DEMO.

`Compare three environment states` is read-only. It checks each frontend against its own branch, compares Supabase TEST against `test`, compares Supabase DEMO against `main`, and reports the Git promotion relationship `develop -> test -> main` as `SAME_COMMIT`, `AHEAD`, `BEHIND`, or `DIVERGED`.

Database results are `ALIGNED`, `BEHIND`, `DRIFT`, or `ERROR`. `BEHIND` is a controlled lag; `DRIFT` means an unexpected migration or hash mismatch. Edge Function source hashes are repository expectations only because this check cannot retrieve deployed source hashes directly from Supabase.

The workflow never deploys, migrates, seeds, or modifies an environment.
