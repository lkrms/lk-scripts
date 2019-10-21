#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/common"

for j in $(seq -1 8); do

    for i in $(seq -1 8); do

        if [ "$i" -ne "-1" ] && [ "$i" -eq "$j" ]; then

            continue

        fi

        FG_COLOUR="colour $i"
        BG_COLOUR="colour $j"

        if [ "$i" -eq "-1" ]; then

            FG_COLOUR="colour N"

        else

            tput setaf "$i"

        fi

        if [ "$j" -eq "-1" ]; then

            BG_COLOUR="colour N"

        else

            tput setab "$j"

        fi

        echo -n "This is $FG_COLOUR on $BG_COLOUR. "

        tput bold

        echo -n "$(upper_first "$FG_COLOUR") with bold. "

        tput sgr0
        [ "$i" -eq "-1" ] || tput setaf "$i"
        [ "$j" -eq "-1" ] || tput setab "$j"

        tput smso

        echo -n "$(upper_first "$FG_COLOUR") with standout. "

        tput bold

        echo "$(upper_first "$FG_COLOUR") with standout and bold."

        tput sgr0

    done

done
