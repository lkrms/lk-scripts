#!/bin/bash

# shellcheck disable=SC1091,SC2015

include='' . lk-bash-load.sh || exit

lk_assert_command_exists mutool

[ "${1:-}" != "--trash" ] || shift

[ "$#" -gt "1" ] && lk_files_exist "$@" || lk_die "Usage: $(basename "$0") [--trash] file1 file2 ..."

for FILE in "$@"; do

    lk_is_pdf "$FILE" || lk_die "$FILE doesn't seem to be a PDF"

done

NEWEST_PATH="$(lk_sort_paths_by_date "$@" | tail -n1)"

PDF_PATH="$(lk_mktemp_file)"
lk_delete_on_exit "$PDF_PATH"

lk_echo_args "$@" | lk_console_list "Combining:" "PDF" "PDFs"
echo

mutool merge -o "$PDF_PATH" "$@" &&
    touch -r "$NEWEST_PATH" "$PDF_PATH" && {

    lk_console_item "Successfully combined to" "$PDF_PATH" "$LK_BOLD$LK_GREEN"
    echo

    lk_console_message "Moving original files out of the way"

    for FILE in "$@"; do

        if lk_command_exists trash-put; then

            trash-put "$FILE" || lk_die

        else

            BACKUP_FILE="$(lk_next_backup_file "$FILE")"
            mv -v "$FILE" "$BACKUP_FILE" || lk_die

        fi

    done

    echo

    lk_console_message "Moving new PDF into place"
    mv -v "$PDF_PATH" "$1" || lk_die

}
