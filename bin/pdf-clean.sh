#!/bin/bash
# shellcheck disable=SC1090,SC2034,SC2015

include='' . lk-bash-load.sh || exit

lk_assert_command_exists mutool
lk_assert_command_exists realpath

[ "$#" -gt "0" ] && lk_files_exist "$@" || lk_die "Usage: $(basename "$0") file ..."

for FILE in "$@"; do

    lk_is_pdf "$FILE" || lk_die "$FILE doesn't seem to be a PDF"

done

# keep the original PDF unless file size is reduced by at least:
PERCENT_SAVED_THRESHOLD="${PERCENT_SAVED_THRESHOLD:-2}"

ERRORS=()

for FILE in "$@"; do

    RFILE="$(realpath "$FILE")"
    cd "$(dirname "$RFILE")"
    PDF_PATH="$(basename "$RFILE")"
    BACKUP_PATH="$(lk_next_backup_file "$PDF_PATH")"

    mv "$PDF_PATH" "$BACKUP_PATH"

    lk_console_item "Cleaning" "$FILE"

    mutool clean -gggg -zfi "$BACKUP_PATH" "$PDF_PATH" &&
        touch -r "$BACKUP_PATH" "$PDF_PATH" || {
        mv -f "$BACKUP_PATH" "$PDF_PATH" || lk_die
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
        lk_echoc "Cleaning was ineffective ($PERCENT_TEXT) so the original will be kept" "$RED"
        mv -f "$BACKUP_PATH" "$PDF_PATH" || lk_die
        continue
    fi

    lk_echoc "Cleaned successfully ($PERCENT_TEXT)" "$LK_GREEN"

done

[ "${#ERRORS[@]}" -eq "0" ] || {

    lk_console_error "Unable to process ${#ERRORS[@]} PDF $(lk_maybe_plural ${#ERRORS[@]} file files)"
    printf '%s\n' "${ERRORS[@]}" >&2
    lk_die

}
