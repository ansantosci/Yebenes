# QUAL-03A - Observational promotion evidence

Adds a read-only check to the existing orchestrator analyze job for DRY_RUN and both promotion modes. No promotion dependency, confirmation, or gate changes.

The source is `develop` for DEVELOP_TO_TEST/DRY_RUN and `test` for TEST_TO_DEMO. The Git **tree SHA** of the source is compared to the Git tree SHA of the commit analyzed by the QUAL-01 workflow on `develop`. This handles different promotion commit histories only when full repository content matches.

The check downloads the existing `qual-01-reports` artifact and requires both ESLint JSON and QUAL-02 comparison JSON. PASS means only that the existing limited cyclomatic comparator returned PASS. It does **not** certify cognitive complexity, security, or all functions. Missing evidence returns INCONCLUSIVE; API or parsing failures return ERROR. Both are informational.

Requires `actions: read` permission for GitHub Actions API; the orchestrator currently declares `contents`, `pages`, and `id-token`, so this patch adds `actions: read` without modifying existing permissions. No secrets beyond the built-in GitHub token. The script never writes to GitHub.

Known limitations: 300-run search cap, 14-day artifact retention, same-content requirement for entire repository (including docs), possible artifacts from analyzer jobs that did not finish every optional analyzer, and a separate unresolved SonarJS failure. No blocking gate should be based on this output.

Validation: run DRY_RUN and inspect the QUAL-03A section and `qual-03-evidence` artifact. Repeat after the next commit in develop and after promotion to test.
