# Environment drift check (ARCH-06 v2)

The project has three Git/Pages environments and two Supabase backends:

- **DEVELOP**: `develop` branch, Pages `/develop/`. No independent Supabase database in the current topology.
- **TEST**: `test` branch, Pages `/test/`, Supabase TEST.
- **DEMO**: `main` branch, root Pages URL, Supabase DEMO.

`Compare three environment states` is read-only. It checks each frontend against its own branch, compares Supabase TEST against `test`, compares Supabase DEMO against `main`, and reports the Git promotion relationship `develop -> test -> main` as `SAME_COMMIT`, `AHEAD`, `BEHIND`, or `DIVERGED`.

Database results are `ALIGNED`, `BEHIND`, `DRIFT`, or `ERROR`. `BEHIND` is a controlled lag; `DRIFT` means an unexpected migration or hash mismatch. Edge Function source hashes are repository expectations only because this check cannot retrieve deployed source hashes directly from Supabase.

The workflow never deploys, migrates, seeds, or modifies an environment.


## Promotion-path classification

Branch ancestry is evaluated with full Git history (`fetch-depth: 0`). The promotion path uses:

- `SAME_COMMIT`: both environment refs point to the same commit.
- `PROMOTED`: the source commit is an ancestor of the target commit; this is the normal result after a pull-request merge promotion.
- `AHEAD`: the source contains the target commit but has not yet been promoted.
- `DIVERGED`: neither commit contains the other; manual reconciliation is required.

A merge commit in TEST or DEMO is therefore not drift by itself. Environment alignment is determined separately from frontend/database state.
