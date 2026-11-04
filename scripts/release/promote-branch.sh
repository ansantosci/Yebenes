#!/usr/bin/env bash
set -euo pipefail
SOURCE="${1:?source branch required}"; DEST="${2:?destination branch required}"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git fetch origin "$SOURCE" "$DEST" --prune
git checkout -B "$DEST" "origin/$DEST"
if git diff --quiet "origin/$DEST" "origin/$SOURCE"; then
  echo "Content already aligned; no merge required."
  exit 0
fi
git merge --no-ff --no-edit "origin/$SOURCE"
git push origin "$DEST"
