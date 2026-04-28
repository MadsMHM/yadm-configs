#!/bin/sh
ps -A -o %cpu | awk -v cores="$(sysctl -n hw.ncpu)" '{s+=$1} END {printf "%.0f%%", s/cores}'
