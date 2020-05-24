#!/bin/bash
# shellcheck disable=SC1090,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_command_exists qpdfview

[ "$#" -gt "0" ] && are_files "$@" || die "Usage: $(basename "$0") /path/to/file.pdf..."

command_exists wmctrl && WINDOW_ID="$(xdotool getactivewindow 2>/dev/null)" || WINDOW_ID=

FILE_NUMBER=0

for FILE_PATH in "$@"; do

    ((++FILE_NUMBER))

    echo

    lk_console_item "Opening file $FILE_NUMBER of $#" "$FILE_PATH"

    nohup qpdfview --unique --instance pdf_rename "$FILE_PATH" >/dev/null 2>&1 &
    disown

    sleep 1

    [ -z "$WINDOW_ID" ] || wmctrl -ia "$WINDOW_ID"

    FILE_NAME="$(basename "$FILE_PATH")"

    NEW_NAME="$(get_value "Rename to:")"

    [ -n "$NEW_NAME" ] || continue

    NEW_NAME="$(lk_maybe_add_extension "$NEW_NAME" ".pdf")"

    [ "$(lower "$FILE_NAME")" != "$(lower "$NEW_NAME")" ] || continue

    NEW_PATH="$(dirname "$FILE_PATH")/$NEW_NAME"
    NEW_PATH="${NEW_PATH#./}"

    NEW_PATH_CLEAN="$NEW_PATH"
    SEQ=1

    while [ -e "$NEW_PATH" ]; do

        ((++SEQ))
        NEW_PATH="$(filename_add_suffix "$NEW_PATH_CLEAN" " ($SEQ)")"

    done

    mv "$FILE_PATH" "$NEW_PATH" || die

    if [ "$NEW_PATH" = "$NEW_PATH_CLEAN" ]; then

        lk_console_item "Renamed to" "$(basename "$NEW_PATH")" "$BOLD$GREEN"

    else

        lk_console_item "$(basename "$NEW_PATH_CLEAN") already exists, renamed to" "$(basename "$NEW_PATH")" "$BOLD$YELLOW"

    fi

done
