#!/bin/bash
# shellcheck disable=SC1090

include='' . lk-bash-load.sh || exit

lk_assert_command_exists gs

[ "$#" -eq "1" ] || lk_die "Usage: $(basename "$0") </path/to/file.pdf>"

lk_is_pdf "$1" || lk_die "$1 doesn't seem to be a PDF"

PDF_PATH="$1"
lk_command_exists realpath && PDF_PATH="$(realpath "$PDF_PATH")" || true

BACKUP_PATH="$(lk_add_file_suffix "$PDF_PATH" "_backup")"

mv -f "$PDF_PATH" "$BACKUP_PATH"

gs -sDEVICE=pdfwrite \
    -sFONTPATH="$FONTPATH" \
    -dPDFSETTINGS=/prepress \
    -dAutoFilterColorImages=false \
    -dAutoFilterGrayImages=false \
    -dColorImageFilter=/FlateEncode \
    -dDownsampleColorImages=false \
    -dDownsampleGrayImages=false \
    -dDownsampleMonoImages=false \
    -dGrayImageFilter=/FlateEncode \
    -o "$PDF_PATH" "$BACKUP_PATH" || {

    mv -f "$BACKUP_PATH" "$PDF_PATH" || true
    lk_die "Unable to embed fonts in $PDF_PATH"

}
