#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

shopt -s nullglob dotglob

FONT_URLS=(
    "https://fonts.google.com/download?family=Source+Code+Pro|Source_Code_Pro.zip"
    "https://fonts.google.com/download?family=Source+Sans+Pro|Source_Sans_Pro.zip"
    "https://fonts.google.com/download?family=Source+Serif+Pro|Source_Serif_Pro.zip"

    # "monospace bitmap font well suited for programming and terminal use"
    "https://font.gohu.org/gohufont-2.1.tar.gz"
)

FONT_CACHE_PATH="$CACHE_DIR/fonts"
mkdir -p "$FONT_CACHE_PATH"
cd "$FONT_CACHE_PATH"

UNPACK_ROOT="$(lk_mktemp_dir)"

lk_console_message "Downloading ${#FONT_URLS[@]} $(single_or_plural "${#FONT_URLS[@]}" font fonts)"
FONT_PATHS="$(lk_download "${FONT_URLS[@]}")"
while IFS= read -r FONT_PATH; do
    lk_console_item "Extracting" "$(basename "$FONT_PATH")"
    case "$FONT_PATH" in
    *.zip)
        EXTRACT_PATH="$UNPACK_ROOT/$(basename "${FONT_PATH%.zip}")"
        mkdir "$EXTRACT_PATH"
        unzip -qq -d "$EXTRACT_PATH" "$FONT_PATH"
        ;;
    *.tar.gz)
        EXTRACT_PATH="$UNPACK_ROOT/$(basename "${FONT_PATH%.tar.gz}")"
        mkdir "$EXTRACT_PATH"
        tar -C "$EXTRACT_PATH" -xf "$FONT_PATH"
        ;;
    *)
        die "$FONT_PATH: unknown archive type"
        ;;
    esac
    CHILDREN=("$EXTRACT_PATH"/*)
    if [ "${#CHILDREN[@]}" -eq "1" ] && [ -d "${CHILDREN[0]}" ]; then
        TEMP_PARENT="$(lk_mktemp_dir)"
        mv -v "${CHILDREN[0]}" "$TEMP_PARENT/"
        mv -v "$TEMP_PARENT"/*/* "$EXTRACT_PATH/"
        rm -Rfv "$TEMP_PARENT"
    fi
done < <(echo "$FONT_PATHS")

# do_fonts_install file_glob subdir_name
function do_fonts_install() {
    local FILENAME TARGET_PATH
    while IFS= read -rd $'\0' FILENAME; do
        TARGET_PATH="$TARGET_DIR/$2/${FILENAME#$UNPACK_ROOT/}"
        mkdir -p "$(dirname "$TARGET_PATH")" &&
            mv -fv "$FILENAME" "$TARGET_PATH" || return
    done < <(find "$UNPACK_ROOT" -type f -iname "$1" -print0)
}

case "$PLATFORM" in

linux)
    TARGET_DIR="/usr/local/share/fonts"
    dir_make_and_own "$TARGET_DIR"
    do_fonts_install "*.ttf" "lk-truetype"
    do_fonts_install "*.otf" "lk-opentype"
    do_fonts_install "*.pcf*" "lk-pcf"
    sudo -H fc-cache --force --verbose
    ;;

*)
    die "$(basename "$0") is not supported on this platform"
    ;;

esac
