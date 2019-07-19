#!/bin/bash

set -euo pipefail

"/opt/Teams for Linux/teams-for-linux" "$@" &

TEAMS_PID=$!

while ps -p "$TEAMS_PID" >/dev/null; do

    sleep 5

    TEAMS_WINDOWS=($(xwininfo -tree -root | grep -E '\("teams for linux" "Teams for Linux"\)[ 0-9+x-]*$' | grep -Eio '\b0x[0-9a-f]+\b')) || continue

    for TEAMS_WINDOW in "${TEAMS_WINDOWS[@]}"; do

        xprop -id "$TEAMS_WINDOW" -f WM_CLASS 8u -set WM_CLASS "teams-for-linux"

    done

done
