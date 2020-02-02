#!/bin/bash
# shellcheck disable=SC1090,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_command_exists mutool

[ "${1:-}" != "--trash" ] || shift

[ "$#" -gt "1" ] && are_files "$@" || die "Usage: $(basename "$0") [--trash] file1 file2 ..."

for FILE in "$@"; do

    is_pdf "$FILE" || die "$FILE doesn't seem to be a PDF"

done

NEWEST_PATH="$(lc_sort_files_by_date "$@" | tail -n1)"

PDF_PATH="$(create_temp_file)"
DELETE_ON_EXIT+=("$PDF_PATH")

lc_echo_array "$@" | lc_console_list "Combining:" "PDF" "PDFs"
echo

mutool merge -o "$PDF_PATH" "$@" &&
    touch -r "$NEWEST_PATH" "$PDF_PATH" && {

    lc_console_item "Successfully combined to" "$PDF_PATH" "$BOLD$GREEN"
    echo

    lc_console_message "Moving original files out of the way"

    for FILE in "$@"; do

        if command_exists trash-put; then

            trash-put "$FILE" || die

        else

            BACKUP_FILE="$(filename_get_next_backup "$FILE" "mutool")"
            mv -v "$FILE" "$BACKUP_FILE" || die

        fi

    done

    echo

    lc_console_message "Moving new PDF into place"
    mv -v "$PDF_PATH" "$1" || die

}
