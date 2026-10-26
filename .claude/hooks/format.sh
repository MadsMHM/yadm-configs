#!/bin/bash
# PostToolUse(Edit|Write): prettier the edited file if the project uses prettier.
# Also marks the session as "edited project code" for the Stop typecheck gate.

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_response.filePath // .tool_input.file_path // empty')
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$f" ] && [ -f "$f" ] || exit 0

# Marker for the Stop gate: only when type-relevant files INSIDE the project change.
if [ -n "$sid" ] && [ -n "$cwd" ]; then
  case "$f" in
    "$cwd"/*)
      case "$f" in
        *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.svelte|*.json)
          touch "/tmp/claude-edited-${sid}" ;;
      esac
      ;;
  esac
fi

case "$f" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.svelte|*.json|*.css|*.scss|*.html|*.md|*.yaml|*.yml) ;;
  *) exit 0 ;;
esac

# Walk up to the nearest package.json; only format if that project depends on prettier.
dir=$(dirname "$f")
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  if [ -f "$dir/package.json" ]; then
    if jq -e '(.devDependencies.prettier // .dependencies.prettier) != null' "$dir/package.json" >/dev/null 2>&1; then
      (cd "$dir" && npx prettier --write --ignore-unknown "$f") >/dev/null 2>&1
    fi
    break
  fi
  dir=$(dirname "$dir")
done

exit 0
