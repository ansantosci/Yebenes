# ARCH-04 main-only infrastructure patch

Apply this patch directly on `main` after aborting the conflicted cherry-pick.

It intentionally contains only files that are safe/necessary on `main`:
- architecture validator updated for `supabase/test-support/`;
- TEST workflow definitions updated to consume test-support from the selected source branch;
- architecture layout documentation.

It intentionally does NOT contain TEST datasets/seeds/test-support SQL, so `main` does not need to acquire synthetic TEST content merely to expose workflows.

After commit/push on main, run `Validate repository architecture` with `source_ref=develop`.
