#!/bin/bash
# PreToolUse(Bash) guard: blocks commands the user always runs manually,
# and destructive operations outside the project directory.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

deny() {
  jq -n --arg reason "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

# Commits, pushes and PR creation are always done manually by the user.
if printf '%s' "$cmd" | grep -Eq '\bgit\b[^|&;]*[[:space:]](commit|push)\b'; then
  deny "Blocked by user policy: git commit/git push are ALWAYS done manually by the user. Stage changes and report what is ready instead."
fi
if printf '%s' "$cmd" | grep -Eq '\bgh\b[^|&;]*\bpr\b[^|&;]*\bcreate\b'; then
  deny "Blocked by user policy: PRs are created manually by the user. Report the suggested title/body instead."
fi

# Destroying uncommitted work is the user's call.
if printf '%s' "$cmd" | grep -Eq '\bgit\b[^|&;]*\breset\b[^|&;]*--hard'; then
  deny "Blocked: git reset --hard destroys uncommitted work. Ask the user to run it manually if intended."
fi
if printf '%s' "$cmd" | grep -Eq '\bgit\b[^|&;]*\bclean\b[^|&;]*-[a-zA-Z]*f'; then
  deny "Blocked: git clean -f deletes untracked files. Ask the user to run it manually if intended."
fi

# Recursive rm: only allowed on relative paths / inside the project / tmp dirs.
if printf '%s' "$cmd" | grep -Eq '\brm\b[[:space:]]+-[a-zA-Z]*[rR]'; then
  for tok in $cmd; do
    case "$tok" in
      "~"*) deny "Blocked: recursive rm targeting the home directory ($tok). Ask the user to run it manually." ;;
      /tmp/*|/private/tmp/*|/var/folders/*) ;;
      /*)
        case "$tok" in
          "$cwd"|"$cwd"/*) ;;
          *) deny "Blocked: recursive rm on a path outside the project ($tok). Ask the user to run it manually." ;;
        esac
        ;;
    esac
  done
fi

exit 0
