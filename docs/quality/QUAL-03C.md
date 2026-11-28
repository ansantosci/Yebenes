# QUAL-03C - Artifact download redirect handling

Scope: read-only quality evidence checker. No changes to release workflow, GitHub permissions, application, or quality-gate behavior.

The GitHub API artifact archive endpoint may return an HTTPS redirect to artifact storage. The checker now disables automatic redirects on authenticated GitHub API calls and performs the artifact download with a new request without Authorization. Non-artifact API redirects are not followed. Errors remain observational and never authorize a release.

Validation: Python compilation and mocked API-to-storage redirect, 401, and invalid redirect tests. GitHub Actions DRY_RUN remains required for live verification.

Expected follow-up: run orchestrator DRY_RUN and inspect QUAL-03A evidence state. A PASS means only the QUAL-02A comparison matched the Git tree, not a complete Sonar Quality Gate.
