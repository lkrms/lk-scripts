#!/bin/bash
# shellcheck disable=SC1090,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_command_exists wget
assert_command_exists unzip

# TODO: move this to config
FONT_URLS=(
    "https://fonts.google.com/download?family=Source+Code+Pro"
    "https://fonts.google.com/download?family=Source+Sans+Pro"
    "https://fonts.google.com/download?family=Source+Serif+Pro"
)

FONT_CACHE_PATH="$CACHE_DIR/fonts"
mkdir -p "$FONT_CACHE_PATH" &&
    [ -w "$FONT_CACHE_PATH" ] &&
    cd "$FONT_CACHE_PATH" || die "Can't write to $FONT_CACHE_PATH"

UNPACK_ROOT="$(create_temp_dir)"
lk_delete_on_exit "$UNPACK_ROOT"

lk_console_message "Downloading ${#FONT_URLS[@]} $(single_or_plural "${#FONT_URLS[@]}" font fonts)"

FONT_PATHS="$(download_urls "${FONT_URLS[@]}")"

while IFS= read -r FONT_PATH; do

    lk_console_item "Extracting" "$(basename "$FONT_PATH")"

    EXTRACT_PATH="$UNPACK_ROOT/$(basename "${FONT_PATH%.zip}")"
    unzip -qq -d "$EXTRACT_PATH" "$FONT_PATH" || die "unzip exit code: $?"

done < <(echo "$FONT_PATHS")

# do_fonts_install file_ext subdir_name
function do_fonts_install() {

    local FILENAME TARGET_PATH

    while IFS= read -rd $'\0' FILENAME; do

        TARGET_PATH="$TARGET_DIR/$2/${FILENAME#$UNPACK_ROOT/}"

        mkdir -p "$(dirname "$TARGET_PATH")" &&
            mv -fv "$FILENAME" "$TARGET_PATH" || die

    done < <(find "$UNPACK_ROOT" -type f -iname "*.$1" -print0)

}

case "$PLATFORM" in

linux)
    TARGET_DIR="/usr/local/share/fonts"

    dir_make_and_own "$TARGET_DIR"

    do_fonts_install "ttf" "lc-truetype"
    do_fonts_install "otf" "lc-opentype"

    sudo -H fc-cache --force --verbose
    ;;

*)
    die "$(basename "$0") is not supported on this platform"
    ;;

esac
