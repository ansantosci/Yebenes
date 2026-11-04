#!/usr/bin/env bash
set -euo pipefail
B="${1:?base ref required}"; S="${2:?source ref required}"
files="$(git diff --name-only "$B" "$S" -- index.html app.js styles.css config.js sw.js version.json manifest.webmanifest assets/|sed '/^$/d')"
[ -n "$files" ]||{ echo "Frontend unchanged: version bump not required.";exit 0;}
bv="$(git show "$B:version.json" 2>/dev/null|tr -d '\r\n '||true)";sv="$(git show "$S:version.json" 2>/dev/null|tr -d '\r\n '||true)"
[ "$bv" != "$sv" ]||{ echo "::error::Frontend changed but version.json did not change.";exit 4;}
echo "Frontend changed and version.json changed."
