#!/bin/sh
# gh-dash D: check out PR $3 of $2 (owner/name) in its local folder $1, then open
# diffnav in a "#<pr>" tab in that repo's Rex session (rex action review_tab) and go there.
dir=$1 repo=$2 pr=$3
fail() { echo "$1"; sleep 3; exit 1; }

[ -n "$dir" ] || fail "$repo has no repoPaths entry in ~/.config/gh-dash/config.yml."
[ -d "$dir" ] || gh repo clone "$repo" "$dir" || fail "Cloning $repo failed."
cd "$dir" || exit 1
# untracked files are fine; tracked edits would block the checkout or ride along onto the PR branch
[ -z "$(git status --porcelain --untracked-files=no)" ] ||
  fail "Uncommitted changes in $dir: commit or stash them first."
gh pr checkout "$pr" || fail "Checking out #$pr failed."
rex do review_tab dir="$dir" pr="$pr" >/dev/null || fail "Couldn't open the Rex tab."
