# QUAL-02A — Baseline comparison (informative)

- Source: QUAL-01C `eslint-report.json`, supplied 28 Nov 2026; 87 findings at cyclomatic threshold 15.
- No automatic baseline updates. Analyzer versions and threshold must remain aligned.
- `PASS`: all uniquely named, matched findings have unchanged or improved complexity, with no ambiguous changes.
- `REGRESSION`: a uniquely matched named function has increased complexity.
- `INCONCLUSIVE`: added/removed/duplicate names or changed anonymous functions require review. These are **not** silently counted as improvements or new findings.
- `ERROR`: missing/invalid report or incompatible baseline.
- The comparison is intentionally conservative and is not a complete detector of regressions in functions below the threshold; adding a newly over-threshold function is flagged as INCONCLUSIVE until reviewed.
- No workflow or promotion blocking; investigate regressions and inconclusive cases manually.
- Cognitive complexity is not measured while SonarJS is failing.
