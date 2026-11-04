#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-DRY_RUN}"
PAIR_SOURCE="${2:-}"
PAIR_DEST="${3:-}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

exclusive_destination_files() {
  local source="$1" destination="$2"
  local s="origin/$source" d="origin/$destination" base
  base="$(git merge-base "$s" "$d")"
  # Files changed by destination since common base, whose resulting blob differs
  # from source. These are real destination-only content changes.
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    local db sb
    db="$(git rev-parse "$d:$path" 2>/dev/null || echo MISSING)"
    sb="$(git rev-parse "$s:$path" 2>/dev/null || echo MISSING)"
    [ "$db" != "$sb" ] && printf '%s\n' "$path"
  done < <(git diff --name-only "$base" "$d")
}

classify() {
  local source="$1" destination="$2"
  local s="origin/$source" d="origin/$destination"
  local changed source_only dest_only dest_exclusive
  changed="$(git diff --name-only "$s" "$d" | sed '/^$/d' | wc -l | tr -d ' ')"
  source_only="$(git rev-list --count "$d..$s")"
  dest_only="$(git rev-list --count "$s..$d")"
  dest_exclusive="$(exclusive_destination_files "$source" "$destination" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [ "$changed" -eq 0 ]; then
    echo OK
  elif [ "$dest_exclusive" -eq 0 ] && [ "$source_only" -gt 0 ]; then
    echo PROMOTION_AVAILABLE
  else
    echo BLOCKED
  fi
}

if [ "$MODE" = "PAIR" ]; then
  classify "$PAIR_SOURCE" "$PAIR_DEST"
  exit 0
fi

detail() {
  local src="$1" dst="$2" label="$3"
  local s="origin/$src" d="origin/$dst" base changed so do_ de st rel f m e ci
  base="$(git merge-base "$s" "$d")"
  changed="$(git diff --name-only "$s" "$d" | sed '/^$/d' | wc -l | tr -d ' ')"
  so="$(git rev-list --count "$d..$s")"
  do_="$(git rev-list --count "$s..$d")"
  de="$(exclusive_destination_files "$src" "$dst" | sed '/^$/d' | wc -l | tr -d ' ')"
  st="$(classify "$src" "$dst")"

  if [ "$changed" -eq 0 ]; then
    if [ "$so" -eq 0 ] && [ "$do_" -eq 0 ]; then rel=IDENTICAL
    elif [ "$so" -eq 0 ]; then rel=DESTINATION_AHEAD_HISTORY_ONLY
    elif [ "$do_" -eq 0 ]; then rel=SOURCE_AHEAD_HISTORY_ONLY
    else rel=SYNCED_CONTENT_DIFFERENT_HISTORY
    fi
  elif [ "$st" = PROMOTION_AVAILABLE ]; then
    if [ "$do_" -gt 0 ]; then rel=SOURCE_CHANGES_WITH_DESTINATION_HISTORY_ONLY
    else rel=SOURCE_AHEAD
    fi
  elif [ "$de" -gt 0 ] && [ "$so" -gt 0 ]; then rel=DIVERGED_WITH_DESTINATION_CONTENT
  else rel=DESTINATION_AHEAD_WITH_CHANGES
  fi

  f="$(git diff --name-only "$d" "$s" -- index.html app.js styles.css config.js sw.js version.json manifest.webmanifest assets/ | sed '/^$/d' | wc -l | tr -d ' ')"
  m="$(git diff --name-only "$d" "$s" -- supabase/migrations/ | sed '/^$/d' | wc -l | tr -d ' ')"
  e="$(git diff --name-only "$d" "$s" -- supabase/functions/ | sed '/^$/d' | wc -l | tr -d ' ')"
  ci="$(git diff --name-only "$d" "$s" -- .github/workflows/ scripts/release/ | sed '/^$/d' | wc -l | tr -d ' ')"

  {
    echo "### $label"; echo
    echo "| Item | Value |"; echo "|---|---|"
    echo "| Status | **$st** |"
    echo "| Git relation | \`$rel\` |"
    echo "| Source-only commits | $so |"
    echo "| Destination-only commits | $do_ |"
    echo "| Destination-exclusive content | $de files |"
    echo "| Content differences | $changed files |"
    echo "| Frontend pending | $f |"
    echo "| Migrations pending | $m |"
    echo "| Edge Functions pending | $e |"
    echo "| CI/CD pending | $ci |"; echo
  } >> "$SUMMARY"

  if [ "$de" -gt 0 ]; then
    {
      echo "<details><summary>Destination-exclusive files (blocking)</summary>"; echo
      echo '```text'; exclusive_destination_files "$src" "$dst"; echo '```'
      echo "</details>"; echo
    } >> "$SUMMARY"
  fi
  if [ "$changed" -gt 0 ]; then
    {
      echo "<details><summary>All files different between source and destination</summary>"; echo
      echo '```text'; git diff --name-status "$d" "$s"; echo '```'
      echo "</details>"; echo
    } >> "$SUMMARY"
  fi
  echo "$st"
}

{
  echo "# Yebenes environment alignment — orchestrator v2.3"; echo
  echo "**Mode:** \`$MODE\`"; echo
} >> "$SUMMARY"

a="$(detail develop test 'DEVELOP -> TEST')"
b="$(detail test main 'TEST -> DEMO (main)')"

{
  echo "## Overall result"; echo
  if [ "$a" = BLOCKED ] || [ "$b" = BLOCKED ]; then
    echo "❌ **At least one environment contains exclusive destination content.**"
  elif [ "$a" = PROMOTION_AVAILABLE ] || [ "$b" = PROMOTION_AVAILABLE ]; then
    echo "🟡 **Validated changes are pending promotion.**"
  else
    echo "✅ **All three environments are aligned in content.**"
  fi
  echo
  echo "v2.3: DEVELOP_TO_TEST enabled; TEST_TO_DEMO remains locked."
} >> "$SUMMARY"
