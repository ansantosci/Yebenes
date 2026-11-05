#!/usr/bin/env bash
set -euo pipefail
B="${1:?base ref required}"; S="${2:?source ref required}"
files="$(git diff --name-only "$B" "$S" -- index.html app.js styles.css config.js sw.js version.json manifest.webmanifest assets/|sed '/^$/d')"
[ -n "$files" ]||{ echo "Frontend unchanged: version bump not required.";exit 0;}
bv="$(git show "$B:version.json" 2>/dev/null|tr -d '\r\n '||true)";sv="$(git show "$S:version.json" 2>/dev/null|tr -d '\r\n '||true)"
[ "$bv" != "$sv" ]||{ echo "::error::Frontend changed but version.json did not change.";exit 4;}

version="$(git show "$S:version.json" | sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)"
[ -n "$version" ]||{ echo "::error::Cannot read frontend version from version.json.";exit 5;}
app_version="$(git show "$S:app.js" | sed -nE "s/^const APP_VERSION='([^']+)';/\1/p" | head -1)"
html_version="$(git show "$S:index.html" | sed -nE "s/.*YEBENES_APP_VERSION[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/p" | head -1)"
[ "$app_version" = "$version" ]||{ echo "::error::app.js APP_VERSION=$app_version but version.json=$version";exit 6;}
[ "$html_version" = "$version" ]||{ echo "::error::index.html YEBENES_APP_VERSION=$html_version but version.json=$version";exit 7;}

bad_refs="$(git show "$S:index.html" | grep -oE '(styles\.css|config\.js|app\.js|madrid-motto-community\.png)\?v=[0-9]+\.[0-9]+\.[0-9]+' | grep -v "?v=$version" || true)"
[ -z "$bad_refs" ]||{ echo "::error::index.html contains cache-busted resources not aligned with v$version:";echo "$bad_refs";exit 8;}

echo "Frontend changed; version $version is consistent across version.json, app.js and index.html."
