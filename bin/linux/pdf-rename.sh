#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_command_exists qpdfview

[ "$#" -gt "0" ] && are_files "$@" || die "Usage: $(basename "$0") /path/to/file.pdf..."

command_exists wmctrl && WINDOW_ID="$(xdotool getactivewindow 2>/dev/null)" || WINDOW_ID=

for FILE_PATH in "$@"; do

    echo

    console_message "${BOLD}Opening:${RESET}" "$FILE_PATH" "$BLUE" "$BOLD"

    nohup qpdfview --unique --instance pdf_rename "$FILE_PATH" >/dev/null 2>&1 &
    disown

    sleep 0.5

    [ -z "$WINDOW_ID" ] || wmctrl -ia "$WINDOW_ID"

    FILE_NAME="$(basename "$FILE_PATH")"

    while :; do

        NEW_NAME="$(get_value "Rename to:")"

        [ -n "$NEW_NAME" ] || continue 2

        NEW_NAME="$(filename_maybe_add_extension "$NEW_NAME" '.pdf')"

        [ "$(lower "$FILE_NAME")" != "$(lower "$NEW_NAME")" ] || continue 2

        NEW_PATH="$(dirname "$FILE_PATH")/$NEW_NAME"
        NEW_PATH="${NEW_PATH#./}"

        [ -e "$NEW_PATH" ] || break

        console_message "File already exists:" "$NEW_PATH" "$BOLD" "$RED"

    done

    mv -v "$FILE_PATH" "$NEW_PATH"

done
