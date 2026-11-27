# QUAL-01C — Analyzer resilience (informative)

Baseline: DEVELOP frontend V96.6.40, backend 110. No application or promotion changes.

## Scope
- Core ESLint is independent of SonarJS plugin initialization.
- Cognitive-complexity analysis is a separate optional step. Its stderr is always archived.
- Both analyzers remain non-blocking; an exit code 2 is a tool failure, **not** a quality PASS.
- Upload-artifact action moved to v6 to address the runner deprecation warning (verify in GitHub Actions).

## Known limitation
The root cause of the SonarJS 3.0.5 `FunctionType` exception is not yet resolved. This patch isolates the failure rather than claiming to fix plugin compatibility. Do not gate promotion on cognitive metrics until a real report is produced.

## Acceptance
1. Core ESLint generates eslint-report.json and the 87 historical complexity findings remain comparable.
2. Cognitive step generates either cognitive-report.json or cognitive-stderr.txt containing the error.
3. actionlint and ShellCheck continue to report independently.
4. No deployment workflows, app.js, backend, or service worker changes.
