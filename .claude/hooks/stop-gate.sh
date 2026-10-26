#!/bin/bash
# Stop: if project code was edited this session, run the project's `check`
# script (svelte-check/tsc). Blocks the stop only when the error count grew
# vs. the stored baseline (ratchet) — pre-existing debt doesn't nag, new
# errors do. Baseline ratchets down as errors get fixed.

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

marker="/tmp/claude-edited-${sid}"
[ -f "$marker" ] || exit 0
rm -f "$marker"

[ -n "$cwd" ] && cd "$cwd" 2>/dev/null
[ -f package.json ] || exit 0
jq -e '.scripts.check' package.json >/dev/null 2>&1 || exit 0

# Never block twice in one stop cycle (loop protection).
[ "$active" = "true" ] && exit 0

runner="npm run"
[ -f bun.lockb ] && runner="bun run"

out=$($runner check 2>&1)
status=$?

basedir="$HOME/.claude/hooks/baselines"
mkdir -p "$basedir"
basefile="$basedir/$(printf '%s' "$cwd" | tr '/' '-').errors"

if [ $status -eq 0 ]; then
  echo 0 > "$basefile"
  exit 0
fi

# svelte-check / tsc summary line: "... N ERRORS ..." / "Found N errors"
errors=$(printf '%s' "$out" | grep -iEo '[0-9]+ error' | tail -1 | grep -Eo '[0-9]+')

if [ -z "$errors" ]; then
  # Can't count errors — treat any failure as blocking.
  { echo "Typecheck gate failed ($runner check). Fix these before finishing:"; printf '%s\n' "$out" | tail -40; } >&2
  exit 2
fi

if [ ! -f "$basefile" ]; then
  echo "$errors" > "$basefile"
  jq -n --arg m "Typecheck gate: baseline initialized at $errors pre-existing error(s) in $(basename "$cwd"). New errors will block from now on." '{systemMessage:$m}'
  exit 0
fi

prev=$(cat "$basefile" 2>/dev/null)
case "$prev" in (*[!0-9]*|"") prev=$errors; esac

if [ "$errors" -le "$prev" ]; then
  echo "$errors" > "$basefile"
  exit 0
fi

{
  echo "Typecheck gate: error count grew from $prev to $errors ($runner check). Fix the NEW errors before finishing (pre-existing baseline: $prev):"
  printf '%s\n' "$out" | grep -iE 'error' | tail -40
} >&2
exit 2
