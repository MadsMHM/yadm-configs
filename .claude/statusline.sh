#!/usr/bin/env bash
# Claude Code status line — tmux-style pills (Tokyo Night):
#   Model · Git branch (● = uncommitted changes) · Lines +/- · Session (5h limit) · Week (7d limit) · Context
# Each pill has a fixed accent; usage % and bar turn green <60%, yellow <85%, red ≥85%. 24h reset times.
# Runs under macOS /bin/bash 3.2: no \u escapes, so glyphs are UTF-8 \x bytes.

input=$(cat)

# Colours are "#rrggbb" (truecolor) or 0-15 (the terminal's own palette).
# Claude Code squashes truecolor to the 256-colour cube, which turns dark navy
# backgrounds into flat grey — so backgrounds and core colours use palette
# indices, which Ghostty's Tokyo Night theme renders exactly.
fg() { case $1 in \#*) printf '\033[38;2;%d;%d;%dm' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}" ;;
                  *) printf '\033[%dm' $(($1 < 8 ? 30 + $1 : 82 + $1)) ;; esac; }
bg() { case $1 in \#*) printf '\033[48;2;%d;%d;%dm' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}" ;;
                  *) printf '\033[%dm' $(($1 < 8 ? 40 + $1 : 92 + $1)) ;; esac; }
RST=$'\033[0m'

# Palette: 0=#15161e 1=#f7768e 2=#9ece6a 3=#e0af68 4=#7aa2f7 5=#bb9af7 6=#7dcfff 7=#a9b1d6 8=#414868
PILL=0 DIM=8 TEXT=7 MUTED='#565f89'
RED=1 GREEN=2 YELLOW=3 BLUE=4 MAGENTA=5 CYAN=6
ORANGE='#ff9e64' TEAL='#73daca' PURPLE='#9d7cd8'   # not in the 16-colour palette; fg-only, so squashing is mild

CAP_L=$(printf '\xee\x82\xb6')        # U+E0B6
CAP_R=$(printf '\xee\x82\xb4')        # U+E0B4
I_MODEL=$(printf '\xf3\xb0\x9a\xa9')  # U+F06A9 robot
I_SESS=$(printf '\xef\x89\x92')       # U+F252 hourglass
I_WEEK=$(printf '\xef\x81\xb3')       # U+F073 calendar
I_CTX=$(printf '\xf3\xb0\xa7\x91')    # U+F09D1 brain
I_BRANCH=$(printf '\xee\x82\xa0')     # U+E0A0 branch
I_DIFF=$(printf '\xef\x93\x92')       # U+F4D2 diff

color_for() {
  if [ "$1" -lt 60 ]; then echo "$GREEN"
  elif [ "$1" -lt 85 ]; then echo "$YELLOW"
  else echo "$RED"
  fi
}

# pill <accent> <icon> <text>: accent-coloured icon on a dim block (lualine-calm), text on PILL
pill() {
  printf '%s%s%s%s%s %s%s %s %s%s%s%s' \
    "$(fg "$DIM")" "$CAP_L" "$(bg "$DIM")" "$(fg "$1")" "$2" \
    "$(bg "$PILL")" "$(fg "$TEXT")" "$3" \
    "$RST" "$(fg "$PILL")" "$CAP_R" "$RST"
}

# bar <pct> <colour>: 8 cells, filled part in colour, rest dim
bar() {
  local width=8 filled=$(($1 * 8 / 100)) i out
  [ $filled -gt $width ] && filled=$width
  out=$(fg "$2")
  for ((i=0; i<filled; i++)); do out+='━'; done
  out+=$(fg "$DIM")
  for ((i=filled; i<width; i++)); do out+='━'; done
  printf '%s%s' "$out" "$(fg "$TEXT")"
}

# Reset timestamp: same day → "HH:MM"; other day → "Ddd HH:MM"
fmt_reset() {
  [ -z "$1" ] || [ "$1" = "0" ] && return
  if [ "$(date '+%F')" = "$(date -r "$1" '+%F' 2>/dev/null)" ]; then
    date -r "$1" '+%H:%M'
  else
    date -r "$1" '+%a %H:%M'
  fi
}

# limit_pill <accent> <icon> <pct> [reset]
limit_pill() {
  if [ -z "$3" ]; then
    pill "$MUTED" "$2" "--"
    return
  fi
  local p c reset text
  p=$(printf '%.0f' "$3")
  c=$(color_for "$p")
  text="$(fg "$c")$p% $(bar "$p" "$c")"
  reset=$(fmt_reset "$4")
  [ -n "$reset" ] && text+=" $(fg "$MUTED")↻ $reset$(fg "$TEXT")"
  pill "$1" "$2" "$text"
}

# One jq pass. "|" separator so `read` keeps empty fields (whitespace IFS collapses them).
IFS='|' read -r model effort dir added removed sess_pct sess_reset week_pct week_reset ctx_pct < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "" | sub(" \\((?<n>\\S+) context\\)"; " \(.n)")),   # "Opus 5.5 (1M context)" → "Opus 5.5 1M"
    (.effort.level // ""),
    (.workspace.current_dir // .cwd // ""),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // ""),
    (.context_window.used_percentage // 0)
  ] | map(tostring) | join("|")' 2>/dev/null
)

# Repo / branch (short sha when detached); --no-optional-locks so we never fight Claude's own git calls.
# Repo name comes from the shared .git dir, so a worktree still shows the main repo's name.
branch_pill=''
if branch=$(git -C "${dir:-.}" --no-optional-locks branch --show-current 2>/dev/null); then
  [ -z "$branch" ] && branch=$(git -C "${dir:-.}" rev-parse --short HEAD 2>/dev/null)
  repo=$(git -C "${dir:-.}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  repo=${repo%/.git}; repo=${repo##*/}
  branch="$repo $(fg "$MUTED")/$(fg "$TEXT") $branch"
  [ -n "$(git -C "${dir:-.}" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ] \
    && branch+=" $(fg "$YELLOW")●$(fg "$TEXT")"
  branch_pill="$(pill "$MAGENTA" "$I_BRANCH" "$branch") "
fi

# Lines changed this session; hidden until Claude has edited something
diff_pill=''
if [ "$added" != 0 ] || [ "$removed" != 0 ]; then
  diff_pill="$(pill "$TEAL" "$I_DIFF" "$(fg "$GREEN")+$added $(fg "$RED")−$removed$(fg "$TEXT")") "
fi

printf '%s %s%s%s %s %s' \
  "$(pill "$ORANGE" "$I_MODEL" "${model:-?}${effort:+ $(fg "$MUTED")·$(fg "$ORANGE") $effort$(fg "$TEXT")}")" \
  "$branch_pill" "$diff_pill" \
  "$(limit_pill "$BLUE" "$I_SESS" "$sess_pct" "$sess_reset")" \
  "$(limit_pill "$CYAN" "$I_WEEK" "$week_pct" "$week_reset")" \
  "$(limit_pill "$PURPLE" "$I_CTX" "$ctx_pct")"
