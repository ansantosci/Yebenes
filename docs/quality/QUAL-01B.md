# QUAL-01B — Informative quality refinements

Baseline: frontend V96.6.40, backend 110. Only QUAL-01 tooling changed.

- Node 24 GitHub Actions major versions: checkout v5, setup-node v5, setup-go v6, upload-artifact v5. Verify in GitHub runner before treating as stable.
- Go setup cache disabled because repository does not contain go.sum.
- actionlint 1.7.7 retains runner ubuntu-26.04; narrowly ignores only its unknown-label diagnostic. Other diagnostics remain visible.
- ESLint 9.39.1 and eslint-plugin-sonarjs 3.0.5: cyclomatic and cognitive complexity warnings at 15, not a Quality Gate.
- Summaries distinguish both complexity metrics; analyzer versions included in artifact.
- No deployment blocking, promotions, backend, frontend version, or runtime behavior changes.
- A successful job does not imply clean code. Initial QUAL-01A baseline was 87 cyclomatic findings; cognitive baseline pending first successful run.
- No suppression of existing injection/security findings; SEC-01 remains separate.
- If plugin installation fails, investigate dependency availability; do not weaken rules to obtain a green report.
