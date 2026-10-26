#!/bin/sh
# Page size is 16K on Apple Silicon (4K on Intel), so read it from vm_stat.
# Anchored patterns: a bare /active:/ also matches "Pages inactive:".
vm_stat | awk -v t="$(sysctl -n hw.memsize)" '
/page size of/ {p=$8}
/^Pages (active|wired down|occupied by compressor):/ {gsub(/\./,"",$NF); u+=int($NF)}
END {printf "%.0f%%", u*p/t*100}'
