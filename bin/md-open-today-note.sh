#!/bin/bash
# shellcheck disable=SC1091

include='' . lk-bash-load.sh || exit

OPEN=${1:-$(lk_is_macos && echo open || echo xdg-open)}

lk_assert_command_exists "$OPEN"

NOTE_DIR="${LK_NOTE_DIR:-$HOME/Documents/Notes}"
TODAY_FILE="$NOTE_DIR/Daily/$(date +'%Y-%m-%d').md"

mkdir -p "$NOTE_DIR/Daily"

[ -e "$TODAY_FILE" ] || {
    printf "**Scratchpad for %s**\n\n\n" "$(date +'%A, %-d %B %Y')" >>"$TODAY_FILE"
}

"$OPEN" "$TODAY_FILE"
