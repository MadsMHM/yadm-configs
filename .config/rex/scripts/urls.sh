#!/bin/sh
# prefix u (tmux-fzf-url): fuzzy-pick URLs from a pane's screen and scrollback, newest
# first, and open them. Tab marks several. $1 is the pane's block ID.

colors="fg:#a9b1d6,hl:#7aa2f7,fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff,pointer:#ff9e64,prompt:#7aa2f7,border:#3b4261,info:#565f89"

urls=$(rex capture -b "$1" --unwrap |
  grep -Eo "(https?|file)://[^][[:space:]<>\"'\`(){}]+" |
  sed 's/[.,;:!?]*$//' |
  tail -r | awk '!seen[$0]++')

[ -n "$urls" ] || { echo "No URLs in this pane."; sleep 1; exit 0; }

printf '%s\n' "$urls" |
  fzf --multi --reverse --prompt '   ' --border-label ' Open URL ' --color "$colors" |
  while IFS= read -r url; do open "$url"; done
