#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-DRY_RUN}"; PS="${2:-}"; PD="${3:-}"; SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

exclusive_destination_files() {
  local source="$1" destination="$2" s="origin/$1" d="origin/$2" base
  base="$(git merge-base "$s" "$d")"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    local db sb
    db="$(git rev-parse "$d:$path" 2>/dev/null || echo MISSING)"
    sb="$(git rev-parse "$s:$path" 2>/dev/null || echo MISSING)"
    [ "$db" != "$sb" ] && printf '%s\n' "$path"
  done < <(git diff --name-only "$base" "$d")
  return 0
}

classify() {
  local source="$1" destination="$2" s="origin/$1" d="origin/$2"
  local changed source_only dest_exclusive
  changed="$(git diff --name-only "$s" "$d"|sed '/^$/d'|wc -l|tr -d ' ')"
  source_only="$(git rev-list --count "$d..$s")"
  dest_exclusive="$(exclusive_destination_files "$source" "$destination"|sed '/^$/d'|wc -l|tr -d ' ')"
  if [ "$changed" -eq 0 ]; then echo OK
  elif [ "$dest_exclusive" -eq 0 ] && [ "$source_only" -gt 0 ]; then echo PROMOTION_AVAILABLE
  else echo BLOCKED
  fi
}
if [ "$MODE" = PAIR ]; then classify "$PS" "$PD"; exit 0; fi

detail() {
 local src="$1" dst="$2" label="$3" s="origin/$1" d="origin/$2"
 local c so do_ de st rel f m e ci
 c="$(git diff --name-only "$s" "$d"|sed '/^$/d'|wc -l|tr -d ' ')"
 so="$(git rev-list --count "$d..$s")"; do_="$(git rev-list --count "$s..$d")"
 de="$(exclusive_destination_files "$src" "$dst"|sed '/^$/d'|wc -l|tr -d ' ')"; st="$(classify "$src" "$dst")"
 if [ "$c" -eq 0 ];then
   if [ "$so" -eq 0 ]&&[ "$do_" -eq 0 ];then rel=IDENTICAL
   elif [ "$so" -eq 0 ];then rel=DESTINATION_AHEAD_HISTORY_ONLY
   elif [ "$do_" -eq 0 ];then rel=SOURCE_AHEAD_HISTORY_ONLY
   else rel=SYNCED_CONTENT_DIFFERENT_HISTORY;fi
 elif [ "$st" = PROMOTION_AVAILABLE ];then
   [ "$do_" -gt 0 ]&&rel=SOURCE_CHANGES_WITH_DESTINATION_HISTORY_ONLY||rel=SOURCE_AHEAD
 elif [ "$de" -gt 0 ]&&[ "$so" -gt 0 ];then rel=DIVERGED_WITH_DESTINATION_CONTENT
 else rel=DESTINATION_AHEAD_WITH_CHANGES;fi
 f="$(git diff --name-only "$d" "$s" -- index.html app.js styles.css config.js sw.js version.json manifest.webmanifest assets/|sed '/^$/d'|wc -l|tr -d ' ')"
 m="$(git diff --name-only "$d" "$s" -- supabase/migrations/|sed '/^$/d'|wc -l|tr -d ' ')"
 e="$(git diff --name-only "$d" "$s" -- supabase/functions/|sed '/^$/d'|wc -l|tr -d ' ')"
 ci="$(git diff --name-only "$d" "$s" -- .github/workflows/ scripts/release/|sed '/^$/d'|wc -l|tr -d ' ')"
 { echo "### $label";echo;echo "| Item | Value |";echo "|---|---|";echo "| Status | **$st** |";echo "| Git relation | \`$rel\` |";echo "| Source-only commits | $so |";echo "| Destination-only commits | $do_ |";echo "| Destination-exclusive content | $de files |";echo "| Content differences | $c files |";echo "| Frontend pending | $f |";echo "| Migrations pending | $m |";echo "| Edge Functions pending | $e |";echo "| CI/CD pending | $ci |";echo; }>>"$SUMMARY"
 if [ "$de" -gt 0 ];then { echo "<details><summary>Destination-exclusive files (blocking)</summary>";echo;echo '```text';exclusive_destination_files "$src" "$dst";echo '```';echo "</details>";echo; }>>"$SUMMARY";fi
 if [ "$c" -gt 0 ];then { echo "<details><summary>All files different</summary>";echo;echo '```text';git diff --name-status "$d" "$s";echo '```';echo "</details>";echo; }>>"$SUMMARY";fi
 echo "$st"
}
{ echo "# Yebenes environment alignment — orchestrator v2.6.0";echo;echo "**Requested mode:** \`$MODE\`";echo; }>>"$SUMMARY"
a="$(detail develop test 'DEVELOP -> TEST')"; b="$(detail test main 'TEST -> DEMO (main)')"
{
 echo "## Environment health";echo
 if [ "$a" = BLOCKED ]||[ "$b" = BLOCKED ];then echo "⚠️ **At least one environment requires synchronization or review.**"
 elif [ "$a" = PROMOTION_AVAILABLE ]||[ "$b" = PROMOTION_AVAILABLE ];then echo "🟡 **Validated changes are pending promotion.**"
 else echo "✅ **All three environments are aligned in content.**";fi
 echo
 case "$MODE" in
   DEVELOP_BACKEND_PREVIEW) echo "**Requested operation:** DEVELOP backend preview → shared TEST backend (no Git promotion)" ;;
   DEVELOP_TO_TEST) echo "**Requested operation:** DEVELOP → TEST" ;;
   TEST_TO_DEMO) echo "**Requested operation:** TEST → DEMO" ;;
   *) echo "**Requested operation:** diagnostic only" ;;
 esac
}>>"$SUMMARY"
