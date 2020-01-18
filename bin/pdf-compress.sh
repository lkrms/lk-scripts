#!/bin/bash
# shellcheck disable=SC1090,SC2034,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_command_exists gs
assert_command_exists realpath

[ "$#" -gt "0" ] && are_files "$@" || die "Usage: $(basename "$0") file ..."

for FILE in "$@"; do

    is_pdf "$FILE" || die "$FILE doesn't seem to be a PDF"

done

# Adobe Distiller defaults (see: https://www.adobe.com/content/dam/acom/en/devnet/acrobat/pdfs/distillerparameters.pdf)
DISTILLER_MINIMUM_QUALITY="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 2.40 /Blend 1 >>"
DISTILLER_LOW_QUALITY="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 1.30 /Blend 1 >>"
DISTILLER_MEDIUM_QUALITY="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 0.76 /Blend 1 >>"
DISTILLER_HIGH_QUALITY="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.40 /Blend 1 >>"
DISTILLER_MAXIMUM_QUALITY="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.15 /Blend 1 >>"

# Ghostscript defaults (see: https://www.ghostscript.com/doc/VectorDevices.htm#note_7)
GS_DEFAULT="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 0.9 /Blend 1 >>"
GS_PRINTER_ACS="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.4 /Blend 1 /ColorTransform 1 >>"
GS_PREPRESS_ACS="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.15 /Blend 1 /ColorTransform 1 >>"
GS_SCREEN_EBOOK_ACS="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 0.76 /Blend 1 /ColorTransform 1 >>"

eval "IMAGE_DICT=\"\$${IMAGE_DICT:-GS_DEFAULT}\""
eval "ACS_IMAGE_DICT=\"\$${ACS_IMAGE_DICT:-IMAGE_DICT}\""

# in my unscientific testing, 144 didn't quite cut it with handwriting
COLOR_DPI="${COLOR_DPI:-200}"
GRAY_DPI="${GRAY_DPI:-200}"
MONO_DPI="${MONO_DPI:-300}"

# only downsample when the ratio of input resolution to output resolution exceeds:
COLOR_DPI_THRESHOLD="${COLOR_DPI_THRESHOLD:-1}"
GRAY_DPI_THRESHOLD="${GRAY_DPI_THRESHOLD:-1}"
MONO_DPI_THRESHOLD="${MONO_DPI_THRESHOLD:-1}"

# keep the original PDF unless file size is reduced by at least:
PERCENT_SAVED_THRESHOLD="${PERCENT_SAVED_THRESHOLD:-1}"

DISTILLER_PARAMS=(
    "/ColorImageDict $IMAGE_DICT"
    "/ColorACSImageDict $ACS_IMAGE_DICT"
    "/ColorImageResolution $COLOR_DPI"
    "/ColorImageDownsampleThreshold $COLOR_DPI_THRESHOLD"
    "/ColorImageDownsampleType /Bicubic"
    "/GrayImageDict $IMAGE_DICT"
    "/GrayACSImageDict $ACS_IMAGE_DICT"
    "/GrayImageResolution $GRAY_DPI"
    "/GrayImageDownsampleThreshold $GRAY_DPI_THRESHOLD"
    "/GrayImageDownsampleType /Bicubic"
    "/MonoImageResolution $MONO_DPI"
    "/MonoImageDownsampleThreshold $MONO_DPI_THRESHOLD"

    # default: true
    "/EmbedAllFonts false"

    # re-encode even if not downsampling
    "/PassThroughJPEGImages false"
)

GS_OPTIONS=(
    -dSAFER
    "-sDEVICE=pdfwrite"
    "-dPDFSETTINGS=${PDFSETTINGS:-/screen}"
    -c "3000000 setvmthreshold << ${DISTILLER_PARAMS[*]} >> setdistillerparams"
)

ERRORS=()

for FILE in "$@"; do

    RFILE="$(realpath "$FILE")"
    cd "$(dirname "$RFILE")"
    PDF_PATH="$(basename "$RFILE")"
    BACKUP_PATH="$(filename_get_next_backup "$PDF_PATH" "gs")"

    mv "$PDF_PATH" "$BACKUP_PATH"

    console_message "Compressing" "$FILE" "$CYAN"

    time_command gs -q -o "$PDF_PATH" "${GS_OPTIONS[@]}" -f "$BACKUP_PATH" &&
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
        echoc "[ $COMMAND_TIME ] Compression was ineffective ($PERCENT_TEXT) so the original will be kept" "$RED"
        mv -f "$BACKUP_PATH" "$PDF_PATH" || die
        continue
    fi

    echoc "[ $COMMAND_TIME ] Compressed successfully ($PERCENT_TEXT)" "$GREEN"

done

[ "${#ERRORS[@]}" -eq "0" ] || {

    console_warning "Unable to process ${#ERRORS[@]} PDF $(single_or_plural ${#ERRORS[@]} file files)" "" "$BOLD$RED"
    printf '%s\n' "${ERRORS[@]}" >&2
    die

}
