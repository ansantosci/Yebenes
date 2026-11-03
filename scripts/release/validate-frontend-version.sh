#!/usr/bin/env bash
set -euo pipefail
source_ref="${1:?source ref required}"
target_ref="${2:?target ref required}"

read_version() {
  git show "origin/$1:version.json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])'
}

source_version="$(read_version "$source_ref")"
target_version="$(read_version "$target_ref")"

mapfile -t frontend_files < <(git diff --name-only "origin/$target_ref..origin/$source_ref" -- \
  index.html app.js styles.css config.js sw.js manifest.webmanifest version.json assets/)

if ((${#frontend_files[@]} == 0)); then
  echo "Frontend unchanged: version bump not required ($source_version)."
  exit 0
fi

if [ "$source_version" = "$target_version" ]; then
  echo "Frontend changed but version.json was not incremented: $source_version" >&2
  printf 'Changed frontend file: %s\n' "${frontend_files[@]}" >&2
  exit 4
fi

echo "Frontend changed and version differs: $target_version -> $source_version"
printf 'Changed frontend file: %s\n' "${frontend_files[@]}"
