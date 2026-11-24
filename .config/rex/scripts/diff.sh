#!/bin/sh
# diffnav for the current branch: its PR's diff from GitHub, or (no PR) the branch vs the
# default branch. Used by the review tab (gh-dash D) and the prefix d / Cmd+I tool.
if ! d=$(gh pr diff 2>/dev/null); then
  base=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null) ||
    { echo "No origin/HEAD here: run git remote set-head origin -a"; sleep 3; exit 1; }
  d=$(git diff "$base"...HEAD)
fi
[ -n "$d" ] || { echo "No changes."; sleep 1; exit 0; }
printf '%s\n' "$d" | diffnav
