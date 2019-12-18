#!/bin/bash
# shellcheck disable=SC1090,SC2034,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_command_exists mutool
assert_command_exists realpath

[ "$#" -gt "0" ] && are_files "$@" || die "Usage: $(basename "$0") file ..."

for FILE in "$@"; do

    is_pdf "$FILE" || die "$FILE doesn't seem to be a PDF"

done

# keep the original PDF unless file size is reduced by at least:
PERCENT_SAVED_THRESHOLD="${PERCENT_SAVED_THRESHOLD:-1}"

ERRORS=()

for FILE in "$@"; do

    RFILE="$(realpath "$FILE")"
    cd "$(dirname "$RFILE")"
    PDF_PATH="$(basename "$RFILE")"
    BACKUP_PATH="$(filename_get_next_backup "$PDF_PATH" "mutool")"

    mv "$PDF_PATH" "$BACKUP_PATH"

    console_message "Cleaning" "$FILE" "$CYAN"

    time_command mutool clean -gggg -zfi "$BACKUP_PATH" "$PDF_PATH" &&
        touch -r "$BACKUP_PATH" "$PDF_PATH" || {
        mv -f "$BACKUP_PATH" "$PDF_PATH" || die
        ERRORS+=("$FILE")
        continue
    }

    OLD_SIZE="$(gnu_stat -Lc %s "$BACKUP_PATH")"
    NEW_SIZE="$(gnu_stat -Lc %s "$PDF_PATH")"
    ((SAVED = OLD_SIZE - NEW_SIZE)) || true

    if [ "$SAVED" -ge "0" ]; then
        ((PERCENT_SAVED = (SAVED * 100 + (OLD_SIZE - 1)) / OLD_SIZE)) || true
        PERCENT_TEXT="saved ${PERCENT_SAVED}% / $((SAVED)) bytes"
        [ "$PERCENT_SAVED" -ge "$PERCENT_SAVED_THRESHOLD" ] || PERCENT_TEXT="only $PERCENT_TEXT"
    else
        ((PERCENT_SAVED = -((OLD_SIZE - 1) - SAVED * 100) / OLD_SIZE)) || true
        PERCENT_TEXT="PDF grew $((-PERCENT_SAVED))% / $((-SAVED)) bytes"
    fi

    if [ "$PERCENT_SAVED" -lt "$PERCENT_SAVED_THRESHOLD" ]; then
        echoc "[ $COMMAND_TIME ] Cleaning was ineffective ($PERCENT_TEXT) so the original will be kept" "$RED"
        mv -f "$BACKUP_PATH" "$PDF_PATH" || die
        continue
    fi

    echoc "[ $COMMAND_TIME ] Cleaned successfully ($PERCENT_TEXT)" "$GREEN"

done

[ "${#ERRORS[@]}" -eq "0" ] || {

    console_warning "Unable to process ${#ERRORS[@]} PDF $(single_or_plural ${#ERRORS[@]} file files)" "" "$BOLD$RED"
    printf '%s\n' "${ERRORS[@]}" >&2
    die

}
