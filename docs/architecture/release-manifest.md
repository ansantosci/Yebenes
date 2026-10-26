# Release Manifest / Environment State (ARCH-05)

Every successful `Promote Yebenes release` run produces a `release-manifest-<ENV>-<run>.json` artifact after architecture guardrails, migrations/contracts, Edge Functions, frontend deployment and smoke tests have passed.

The manifest records the promoted source ref and exact Git commit, frontend version from `version.json`, baseline manifest, complete migration inventory and highest migration number, SHA-256 of every versioned Edge Function, verification results and GitHub Actions run identifiers.

It is descriptive evidence of the release that completed successfully. It contains no credentials, user data or environment secrets. TEST and DEMO remain separate environments; equal release manifests mean code/schema release alignment, not equality of data, users, Auth settings, secrets, Storage contents, Vault or Cron configuration.

The artifact is retained for 90 days. ARCH-06 consumes the same model to compare expected Git state with environment state without modifying either environment.
