#!/bin/sh
# Bail before launching osascript at all when Spotify is closed — Apple Events
# can block for seconds and this runs on every status-bar refresh.
pgrep -xq Spotify || exit 0
t=$(osascript -e '
if application "Spotify" is running then
  tell application "Spotify"
    if player state is playing then
      set t to artist of current track & " - " & name of current track
      if length of t > 30 then
        set t to text 1 thru 30 of t & "…"
      end if
      return t
    end if
  end tell
end if' 2>/dev/null)
# Status-bar pill; octal escapes are UTF-8 for U+E0B6 (left cap), U+F001 (music), U+E0B4 (right cap)
[ -n "$t" ] && printf '#[fg=#3b4261,bg=default]\356\202\266#[fg=#7dcfff,bg=#3b4261]\357\200\201 #[fg=#a9b1d6,bg=#292e42] %s #[fg=#292e42,bg=default]\356\202\264 ' "$t"
