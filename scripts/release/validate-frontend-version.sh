#!/usr/bin/env bash
set -euo pipefail
BASE="${1:?base ref required}"
SOURCE="${2:?source ref required}"
files="$(git diff --name-only "$BASE" "$SOURCE" -- index.html app.js styles.css config.js sw.js version.json manifest.webmanifest assets/ | sed '/^$/d')"
if [ -z "$files" ]; then
  echo "Frontend unchanged: version bump not required."
  exit 0
fi
base_version="$(git show "$BASE:version.json" 2>/dev/null | tr -d '\r\n ' || true)"
source_version="$(git show "$SOURCE:version.json" 2>/dev/null | tr -d '\r\n ' || true)"
if [ "$base_version" = "$source_version" ]; then
  echo "::error::Frontend changed but version.json did not change."
  exit 4
fi
echo "Frontend changed and version.json changed."
