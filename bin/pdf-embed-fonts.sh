#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_command_exists gs

[ "$#" -eq "1" ] || die "Usage: $(basename "$0") </path/to/file.pdf>"

is_pdf "$1" || die "$1 doesn't seem to be a PDF"

PDF_PATH="$1"
command_exists realpath && PDF_PATH="$(realpath "$PDF_PATH")" || true

BACKUP_PATH="$(filename_add_suffix "$PDF_PATH" "_backup")"

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
    die "Unable to embed fonts in $PDF_PATH"

}
