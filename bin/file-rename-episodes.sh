#!/bin/bash
# shellcheck disable=SC1090,SC2034

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

DRYRUN_BY_DEFAULT=Y
dryrun_message

RENAME_ROOT="$(realpath "${1:-.}")"
RENAME_ROOT_PARENT="$(dirname "$RENAME_ROOT")"

LAST_DIRNAME=

while read -rd $'\0' FILE_PATH; do

    DIRNAME="$(dirname "$FILE_PATH")"
    DIRNAME="${DIRNAME#$RENAME_ROOT_PARENT}"

    if [ "$DIRNAME" != "$LAST_DIRNAME" ]; then

        COUNT=0

        SERIES_NAME="$(basename "$(dirname "$DIRNAME")")"
        SEASON_NAME="$(basename "$DIRNAME")"

        [ "$SERIES_NAME" != "/" ] || SERIES_NAME=
        [ "$SEASON_NAME" != "/" ] || SEASON_NAME=

        if [ -z "$SERIES_NAME" ] || [ -z "${SEASON_NAME//[^0-9]/}" ]; then

            SERIES_NAME="$SEASON_NAME"
            SEASON_NAME=

        else

            SEASON_NAME="_S${SEASON_NAME//[^0-9]/}"

        fi

        [ -n "$SERIES_NAME" ] || die "Unable to determine series name for $FILE_PATH"

        LAST_DIRNAME="$DIRNAME"

    fi

    FILE_NAME="$(basename "$FILE_PATH")"
    FILE_EXT="${FILE_PATH##*.}"
    [ "$FILE_EXT" != "mp4" ] || FILE_EXT="m4v"

    ! [[ "${FILE_NAME#${SERIES_NAME}${SEASON_NAME}_E}" =~ ^[0-9]{2}\."$FILE_EXT"$ ]] || {
        lc_console_item "Skipping (already renamed)" "$FILE_PATH" "$BOLD$RED"
        continue
    }

    while :; do

        ((++COUNT))
        PADDED_COUNT="$(printf "%02d" "$COUNT")"

        NEW_FILENAME="${SERIES_NAME}${SEASON_NAME}_E${PADDED_COUNT}.${FILE_EXT}"
        NEW_PATH="$(dirname "$FILE_PATH")/$NEW_FILENAME"

        [ -e "$NEW_PATH" ] || break

    done

    [[ "$FILE_NAME" =~ [^0-9]"$COUNT"[^0-9] ]] || lc_console_item "WARNING: this doesn't look like an episode $COUNT:" "$FILE_PATH" "$BOLD$RED"

    maybe_dryrun mv -vn "$FILE_PATH" "$NEW_PATH" || die

done < <(find "$RENAME_ROOT" -type f \( -name '*.m4v' -o -name '*.mkv' -o -name '*.mp4' \) ! -name '.*' -print0 | sort -zV)
