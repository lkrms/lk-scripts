#!/bin/bash
# shellcheck disable=SC1090,SC2015

include='' . lk-bash-load.sh || exit

lk_assert_command_exists qpdfview

[ "$#" -gt "0" ] && lk_files_exist "$@" || lk_die "Usage: $(basename "$0") /path/to/file.pdf..."

lk_command_exists wmctrl && WINDOW_ID="$(xdotool getactivewindow 2>/dev/null)" || WINDOW_ID=

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

    NEW_NAME="$(lk_console_read "Rename to:")"

    [ -n "$NEW_NAME" ] || continue

    NEW_NAME="$(lk_file_maybe_add_extension "$NEW_NAME" ".pdf")"

    [ "$(lk_lower "$FILE_NAME")" != "$(lk_lower "$NEW_NAME")" ] || continue

    NEW_PATH="$(dirname "$FILE_PATH")/$NEW_NAME"
    NEW_PATH="${NEW_PATH#./}"

    NEW_PATH_CLEAN="$NEW_PATH"
    SEQ=1

    while [ -e "$NEW_PATH" ]; do

        ((++SEQ))
        NEW_PATH="$(lk_file_add_suffix "$NEW_PATH_CLEAN" " ($SEQ)")"

    done

    mv "$FILE_PATH" "$NEW_PATH" || lk_die

    if [ "$NEW_PATH" = "$NEW_PATH_CLEAN" ]; then

        lk_console_item "Renamed to" "$(basename "$NEW_PATH")" "$LK_BOLD$LK_GREEN"

    else

        lk_console_item "$(basename "$NEW_PATH_CLEAN") already exists, renamed to" "$(basename "$NEW_PATH")" "$LK_BOLD$LK_YELLOW"

    fi

done
