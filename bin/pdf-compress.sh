#!/bin/bash
# shellcheck disable=SC1091,SC2015,SC2034

include='' . lk-bash-load.sh || exit

lk_assert_command_exists gs

[ $# -gt 0 ] && lk_files_exist "$@" || lk_usage "\
Usage: ${0##*/} PDF_FILE..."

for FILE in "$@"; do
    lk_is_pdf "$FILE" || lk_die "not a PDF: $FILE"
done

# Adobe Distiller defaults (see:
# https://www.adobe.com/content/dam/acom/en/devnet/acrobat/pdfs/distillerparameters.pdf)
DISTILLER_MINIMUM_QUALITY="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 2.40 /Blend 1 >>"
DISTILLER_LOW_QUALITY="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 1.30 /Blend 1 >>"
DISTILLER_MEDIUM_QUALITY="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 0.76 /Blend 1 >>"
DISTILLER_HIGH_QUALITY="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.40 /Blend 1 >>"
DISTILLER_MAXIMUM_QUALITY="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.15 /Blend 1 >>"

# Ghostscript defaults (see:
# https://www.ghostscript.com/doc/VectorDevices.htm#note_7)
GS_DEFAULT="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 0.9 /Blend 1 >>"
GS_PRINTER_ACS="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.4 /Blend 1 /ColorTransform 1 >>"
GS_PREPRESS_ACS="<< /HSamples [1 1 1 1] /VSamples [1 1 1 1] /QFactor 0.15 /Blend 1 /ColorTransform 1 >>"
GS_SCREEN_EBOOK_ACS="<< /HSamples [2 1 1 2] /VSamples [2 1 1 2] /QFactor 0.76 /Blend 1 /ColorTransform 1 >>"

IMAGE_DICT=${IMAGE_DICT:-GS_DEFAULT}
ACS_IMAGE_DICT=${ACS_IMAGE_DICT:-IMAGE_DICT}

# In my unscientific testing, 144 didn't quite cut it with handwriting
COLOR_DPI=${COLOR_DPI:-200}
GRAY_DPI=${GRAY_DPI:-200}
MONO_DPI=${MONO_DPI:-300}

# Only downsample when the ratio of input resolution to output resolution
# exceeds:
COLOR_DPI_THRESHOLD=${COLOR_DPI_THRESHOLD:-1}
GRAY_DPI_THRESHOLD=${GRAY_DPI_THRESHOLD:-1}
MONO_DPI_THRESHOLD=${MONO_DPI_THRESHOLD:-1}

# Keep the original PDF unless file size is reduced by at least this much
PERCENT_SAVED_THRESHOLD=${PERCENT_SAVED_THRESHOLD:-2}

IMAGE_DICT=${!IMAGE_DICT}
ACS_IMAGE_DICT=${!ACS_IMAGE_DICT}

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

    # Default: true
    "/EmbedAllFonts false"

    # Re-encode even if not downsampling
    "/PassThroughJPEGImages false"
)

GS_OPTIONS=(
    -dSAFER
    "-sDEVICE=pdfwrite"
    "-dPDFSETTINGS=${PDFSETTINGS:-/screen}"
    -c "3000000 setvmthreshold << ${DISTILLER_PARAMS[*]} >> setdistillerparams"
)

ERRORS=()

i=0
for FILE in "$@"; do
    lk_console_message "$FILE ($((++i)) of $#)"
    PDF_PATH=$(lk_mktemp_file)
    lk_delete_on_exit "$PDF_PATH"
    gs -q -o "$PDF_PATH" "${GS_OPTIONS[@]}" -f "$FILE" &&
        touch -r "$FILE" "$PDF_PATH" || {
        ERRORS+=("$FILE")
        continue
    }
    OLD_SIZE=$(gnu_stat -Lc %s "$FILE")
    NEW_SIZE=$(gnu_stat -Lc %s "$PDF_PATH")
    ((SAVED = OLD_SIZE - NEW_SIZE)) || true
    if [ "$SAVED" -ge 0 ]; then
        ((PERCENT_SAVED = (SAVED * 100 + (OLD_SIZE - 1)) / OLD_SIZE)) || true
        lk_console_detail "File size" \
            "reduced by ${PERCENT_SAVED}% / $((SAVED)) bytes"
    else
        ((PERCENT_SAVED = -((OLD_SIZE - 1) - SAVED * 100) / OLD_SIZE)) || true
        lk_console_detail "File size" \
            "increased by $((-PERCENT_SAVED))% / $((-SAVED)) bytes"
    fi
    if [ "$PERCENT_SAVED" -lt "$PERCENT_SAVED_THRESHOLD" ]; then
        lk_console_detail "Keeping original:" "$FILE" "$LK_BOLD$LK_RED"
        continue
    fi
    if lk_command_exists trash-put; then
        trash-put "$FILE"
    else
        BACKUP_FILE=$(lk_next_backup_file "$FILE")
        mv -v "$FILE" "$BACKUP_FILE"
    fi
    mv "$PDF_PATH" "$FILE"
    lk_console_detail "Compressed successfully:" "$FILE"
done
[ "${#ERRORS[@]}" -eq 0 ] || {
    lk_echo_array ERRORS |
        lk_console_list "Unable to process:" file files "$LK_BOLD$LK_RED"
    lk_die ""
}
