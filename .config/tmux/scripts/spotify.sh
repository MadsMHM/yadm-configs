#!/bin/sh
osascript -e '
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
end if' 2>/dev/null
