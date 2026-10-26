#!/bin/bash
# Stop + Notification: macOS notification when Claude finishes a long turn
# (>30s since prompt) or needs attention (permission prompt / idle).

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
proj=$(basename "${cwd:-$PWD}")

if [ "$event" = "Notification" ]; then
  msg=$(printf '%s' "$input" | jq -r '.message // "Claude needs your attention"')
else
  # Stop fires on clear/resume/compact too — only notify for real turns
  # that started >30s ago (marker written by turnstart.sh on prompt submit).
  mark="/tmp/claude-turnstart-${sid}"
  [ -f "$mark" ] || exit 0
  start=$(cat "$mark" 2>/dev/null)
  rm -f "$mark"
  now=$(date +%s)
  case "$start" in (*[!0-9]*|"") exit 0 ;; esac
  [ $((now - start)) -ge 30 ] || exit 0
  msg="Finished — ready for review"
fi

msg=${msg//\"/}
proj=${proj//\"/}
osascript -e "display notification \"$msg\" with title \"Claude Code — $proj\"" >/dev/null 2>&1 || true
exit 0
