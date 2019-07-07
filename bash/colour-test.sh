#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common"

for j in $(seq -1 8); do

    for i in $(seq -1 8); do

        [ "$i" -ne "-1" -a "$i" -eq "$j" ] && continue

        FG_COLOUR="colour $i"
        BG_COLOUR="colour $j"

        [ "$i" -eq "-1" ] && FG_COLOUR="colour N" || tput setaf $i
        [ "$j" -eq "-1" ] && BG_COLOUR="colour N" || tput setab $j

        echo -n "This is $FG_COLOUR on $BG_COLOUR. "

        tput bold

        echo -n "$(upper_first "$FG_COLOUR") with bold. "

        tput sgr0
        [ "$i" -eq "-1" ] || tput setaf $i
        [ "$j" -eq "-1" ] || tput setab $j

        tput smso

        echo -n "$(upper_first "$FG_COLOUR") with standout. "

        tput bold

        echo "$(upper_first "$FG_COLOUR") with standout and bold."

        tput sgr0

    done

done
