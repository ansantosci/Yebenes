#!/usr/bin/env bash
set -euo pipefail

mode="${1:-DRY_RUN}"
case "$mode" in
  DRY_RUN|DEVELOP_TO_TEST) source_ref=develop; target_ref=test ;;
  TEST_TO_DEMO) source_ref=test; target_ref=main ;;
  *) echo "Unsupported mode: $mode" >&2; exit 2 ;;
esac

git fetch --no-tags origin develop test main
source_sha="$(git rev-parse "origin/$source_ref")"
target_sha="$(git rev-parse "origin/$target_ref")"
merge_base="$(git merge-base "$source_sha" "$target_sha")"

if [ "$source_sha" = "$target_sha" ]; then relation=ALIGNED
elif git merge-base --is-ancestor "$target_sha" "$source_sha"; then relation=SOURCE_AHEAD
elif git merge-base --is-ancestor "$source_sha" "$target_sha"; then relation=DESTINATION_AHEAD
else relation=DIVERGED
fi

mapfile -t files < <(git diff --name-only "$target_sha..$source_sha" | sort)
mapfile -t commits < <(git log --format='%h %s' "$target_sha..$source_sha")

frontend=0; migrations=0; edge=0; workflows=0
for f in "${files[@]}"; do
  case "$f" in
    index.html|app.js|styles.css|config.js|sw.js|manifest.webmanifest|version.json|assets/*) frontend=1 ;;
  esac
  [[ "$f" == supabase/migrations/*.sql ]] && migrations=1
  [[ "$f" == supabase/functions/* ]] && edge=1
  [[ "$f" == .github/workflows/* ]] && workflows=1
done

{
  echo "### Promotion analysis"
  echo
  echo "| Item | Value |"
  echo "|---|---|"
  echo "| Mode | \`$mode\` |"
  echo "| Source | \`$source_ref\` |"
  echo "| Destination | \`$target_ref\` |"
  echo "| Git relation | **$relation** |"
  echo "| Source commit | \`$source_sha\` |"
  echo "| Destination commit | \`$target_sha\` |"
  echo "| Merge base | \`$merge_base\` |"
  echo "| Changed files | ${#files[@]} |"
  echo "| Frontend changed | $frontend |"
  echo "| Migrations changed | $migrations |"
  echo "| Edge Functions changed | $edge |"
  echo "| Workflows changed | $workflows |"
  echo
  echo "#### Commits pending promotion"
  if ((${#commits[@]})); then printf '%s\n' "${commits[@]}" | sed 's/^/- `/' | sed 's/$/`/'; else echo '- None'; fi
  echo
  echo "#### Files changed"
  if ((${#files[@]})); then printf '%s\n' "${files[@]}" | sed 's/^/- `/' | sed 's/$/`/'; else echo '- None'; fi
} | tee promotion-analysis.md

printf 'source_ref=%s\n' "$source_ref" >> "$GITHUB_OUTPUT"
printf 'target_ref=%s\n' "$target_ref" >> "$GITHUB_OUTPUT"
printf 'relation=%s\n' "$relation" >> "$GITHUB_OUTPUT"
printf 'source_sha=%s\n' "$source_sha" >> "$GITHUB_OUTPUT"
printf 'target_sha=%s\n' "$target_sha" >> "$GITHUB_OUTPUT"
printf 'frontend_changed=%s\n' "$frontend" >> "$GITHUB_OUTPUT"
printf 'migrations_changed=%s\n' "$migrations" >> "$GITHUB_OUTPUT"
printf 'edge_changed=%s\n' "$edge" >> "$GITHUB_OUTPUT"
printf 'workflows_changed=%s\n' "$workflows" >> "$GITHUB_OUTPUT"
printf 'changed_files=%s\n' "${#files[@]}" >> "$GITHUB_OUTPUT"

# Promotion is only safe when destination is an ancestor of source, or already aligned.
case "$relation" in
  ALIGNED|SOURCE_AHEAD) ;;
  DESTINATION_AHEAD|DIVERGED)
    echo "PROMOTION BLOCKED: $target_ref contains history not safely represented by $source_ref ($relation)." >&2
    exit 3
    ;;
esac
