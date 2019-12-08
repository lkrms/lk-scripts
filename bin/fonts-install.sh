#!/bin/bash
# shellcheck disable=SC1090

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
mkdir -p "$FONT_CACHE_PATH" && [ -w "$FONT_CACHE_PATH" ] && cd "$FONT_CACHE_PATH" || die "Can't write to $FONT_CACHE_PATH"

UNPACK_ROOT="$(create_temp_dir Y)"
DELETE_ON_EXIT+=("$UNPACK_ROOT")

console_message "Downloading ${#FONT_URLS[@]} $(single_or_plural "${#FONT_URLS[@]}" font fonts)" "$CYAN"

FONT_PATHS="$(
    . "$SUBSHELL_SCRIPT_PATH" || exit
    download_urls "${FONT_URLS[@]}"
)"

while IFS= read -r FONT_PATH; do

    console_message "Extracting:" "$(basename "$FONT_PATH")" "$CYAN"

    EXTRACT_PATH="$UNPACK_ROOT/$(basename "$FONT_PATH")"
    EXTRACT_PATH="${EXTRACT_PATH%.zip}"
    unzip -qq -d "$EXTRACT_PATH" "$FONT_PATH" || die "unzip exit code: $?"

done < <(echo "$FONT_PATHS")

case "$PLATFORM" in

linux)
    sudo fc-cache --system-only --force --verbose
    ;;

*)
    die "$(basename "$0") is not supported on this platform"
    ;;

esac
