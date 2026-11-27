# QUAL-01A — Informative code-quality baseline

Status: approved design; patch for review, not deployed.
Baseline frontend: V96.6.40; backend: 110. Target branch: develop.

## Scope
- Independent `.github/workflows/code-quality.yml` on pushes to `develop` and manual runs.
- ESLint 9.39.1 for JavaScript; actionlint 1.7.7; ShellCheck from Ubuntu package repository (record actual version in run).
- Read-only workflow permissions; no deployment secrets, no changes to promotion, Service Worker, versioning, or Supabase.
- Reports in job summary and 14-day artifact; non-blocking while baseline is established.

## Caveats
- An informational green workflow is not a passed Quality Gate.
- ESLint cyclomatic complexity is not Sonar cognitive complexity; this is not equivalent to Sonar analysis.
- ShellCheck package version depends on the Ubuntu runner; pin it in a later approved iteration if necessary.
- SonarCloud currently analyzes `main`; multi-branch behavior under Free is not assumed.
- This first iteration does not compare to historical issues automatically; the first run establishes the baseline, later changes require a separate comparison design.
- SEC-01 workflow-injection findings are a separate security review; actionlint alone does not guarantee their detection.

## Acceptance
- Trigger on `develop`, run independent of deploy workflows.
- Reports generated, including analyzer installation failures.
- No deployment, database, RBAC, cache or version modifications.
- Review first run and record measured counts in the next Continuity Master checkpoint.
