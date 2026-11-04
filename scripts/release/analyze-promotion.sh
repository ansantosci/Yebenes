#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-DRY_RUN}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

classify_pair() {
  local source="$1" destination="$2" label="$3"
  local s="origin/$source" d="origin/$destination"
  local source_sha dest_sha changed_count source_only dest_only relation status
  source_sha="$(git rev-parse "$s")"; dest_sha="$(git rev-parse "$d")"
  changed_count="$(git diff --name-only "$s" "$d" | sed '/^$/d' | wc -l | tr -d ' ')"
  source_only="$(git rev-list --count "$d..$s")"; dest_only="$(git rev-list --count "$s..$d")"
  if [ "$changed_count" -eq 0 ]; then
    if [ "$source_sha" = "$dest_sha" ]; then relation="IDENTICAL"
    elif [ "$source_only" -eq 0 ] && [ "$dest_only" -gt 0 ]; then relation="DESTINATION_AHEAD_HISTORY_ONLY"
    elif [ "$source_only" -gt 0 ] && [ "$dest_only" -eq 0 ]; then relation="SOURCE_AHEAD_HISTORY_ONLY"
    else relation="SYNCED_CONTENT_DIFFERENT_HISTORY"; fi
    status="OK"
  elif [ "$source_only" -gt 0 ] && [ "$dest_only" -eq 0 ]; then relation="SOURCE_AHEAD"; status="PROMOTION_AVAILABLE"
  elif [ "$source_only" -eq 0 ] && [ "$dest_only" -gt 0 ]; then relation="DESTINATION_AHEAD_WITH_CHANGES"; status="BLOCKED"
  else relation="DIVERGED"; status="BLOCKED"; fi
  local frontend migrations edge cicd
  frontend="$(git diff --name-only "$d" "$s" -- index.html app.js styles.css config.js sw.js version.json manifest.webmanifest assets/ | sed '/^$/d' | wc -l | tr -d ' ')"
  migrations="$(git diff --name-only "$d" "$s" -- supabase/migrations/ | sed '/^$/d' | wc -l | tr -d ' ')"
  edge="$(git diff --name-only "$d" "$s" -- supabase/functions/ | sed '/^$/d' | wc -l | tr -d ' ')"
  cicd="$(git diff --name-only "$d" "$s" -- .github/workflows/ scripts/release/ | sed '/^$/d' | wc -l | tr -d ' ')"
  {
    echo "### $label"; echo
    echo "| Item | Value |"; echo "|---|---|"
    echo "| Source | \`$source\` |"; echo "| Destination | \`$destination\` |"
    echo "| Status | **$status** |"; echo "| Git relation | \`$relation\` |"
    echo "| Source-only commits | $source_only |"; echo "| Destination-only commits | $dest_only |"
    echo "| Content differences | $changed_count files |"; echo "| Frontend pending | $frontend |"
    echo "| Migrations pending | $migrations |"; echo "| Edge Functions pending | $edge |"
    echo "| CI/CD pending | $cicd |"; echo
  } >> "$SUMMARY"
  if [ "$changed_count" -gt 0 ]; then
    { echo "<details><summary>Files different</summary>"; echo; echo '```text'; git diff --name-status "$d" "$s"; echo '```'; echo "</details>"; echo; } >> "$SUMMARY"
  fi
  echo "$status"
}
{
 echo "# Yebenes environment alignment"; echo
 echo "**Mode:** \`$MODE\`"; echo
 echo "> Diagnostic only: no branch, database or deployment is modified."; echo
} >> "$SUMMARY"
s1="$(classify_pair develop test 'DEVELOP -> TEST')"
s2="$(classify_pair test main 'TEST -> DEMO (main)')"
{
 echo "## Overall result"; echo
 if [ "$s1" = "BLOCKED" ] || [ "$s2" = "BLOCKED" ]; then
   echo "❌ **Environment drift requires attention. Promotion remains blocked.**"
 elif [ "$s1" = "PROMOTION_AVAILABLE" ] || [ "$s2" = "PROMOTION_AVAILABLE" ]; then
   echo "🟡 **At least one environment has changes pending promotion.**"
 else
   echo "✅ **All three environments are aligned in content. Extra merge-history commits are accepted.**"
 fi
 echo; echo "Promotion modes remain locked in v2.1."
} >> "$SUMMARY"
