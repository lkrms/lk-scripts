#!/bin/bash
# shellcheck disable=SC1090

include='' . lk-bash-load.sh || exit

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

            lk_safe_tput setaf "$i"

        fi

        if [ "$j" -eq "-1" ]; then

            BG_COLOUR="colour N"

        else

            lk_safe_tput setab "$j"

        fi

        printf 'This is %s on %s. ' "$FG_COLOUR" "$BG_COLOUR"

        lk_safe_tput dim

        printf '%s with dim. ' "$(lk_upper_first "$FG_COLOUR")"

        lk_safe_tput bold

        printf '%s with bold. ' "$(lk_upper_first "$FG_COLOUR")"

        lk_safe_tput sgr0
        [ "$i" -eq "-1" ] || lk_safe_tput setaf "$i"
        [ "$j" -eq "-1" ] || lk_safe_tput setab "$j"

        lk_safe_tput smso

        printf '%s with standout. ' "$(lk_upper_first "$FG_COLOUR")"

        lk_safe_tput bold

        printf '%s with standout and bold.' "$(lk_upper_first "$FG_COLOUR")"

        lk_safe_tput sgr0

        printf '\n'

    done

done
