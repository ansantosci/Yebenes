# QUAL-03B — Diagnose GitHub evidence HTTP errors

Scope: read-only diagnostic change to `scripts/quality/check_promotion_evidence.py`.

The existing `GH_TOKEN` mapping and `actions: read` permission are retained. HTTP errors now report the stage (`list_quality_runs`, `read_commit_tree`, `list_run_artifacts`, or `download_report_artifact`) and HTTP status, without exposing credentials, signed URLs, or response bodies.

This does not change the result classifications or release gates. Execute the existing orchestrator in DRY_RUN and inspect the QUAL-03A evidence reason. A 401 at artifact download needs a different investigation from a 401 at the initial API call. No frontend, backend, cache, or promotion logic changes.
