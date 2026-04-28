#!/bin/sh
vm_stat | awk -v t="$(sysctl -n hw.memsize)" '
/active:|wired down:|occupied by compressor:/ {gsub(/\./,"",$NF); u+=int($NF)}
END {printf "%.0f%%", u*4096/t*100}'
