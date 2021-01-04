#!/bin/bash

# shellcheck disable=SC1091

include='' . lk-bash-load.sh || exit

OPEN_COMMAND=$(lk_command_first_existing xdg-open open) ||
    lk_die "xdg-open or equivalent not found"

NOTE_DIR=${LK_NOTE_DIR:-~/Documents/Notes}
TODAY_FILE=$NOTE_DIR/Daily/$(lk_date "%Y-%m-%d").md

mkdir -p "${TODAY_FILE%/*}"

[ -e "$TODAY_FILE" ] || {
    printf "**Scratchpad for %s**\n\n\n" "$(lk_date "%A, %-d %B %Y")" \
        >>"$TODAY_FILE"
}

"$OPEN_COMMAND" "$TODAY_FILE"
