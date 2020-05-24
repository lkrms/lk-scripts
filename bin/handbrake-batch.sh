#!/bin/bash
# shellcheck disable=SC1090,SC2124,SC2198,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

if lk_files_exist "$@"; then
    SOURCE_FILES=("$@")
elif [ "$#" -gt "1" ] && lk_files_exist "${@:1:$#-1}" && [ -d "${@: -1}" ]; then
    SOURCE_FILES=("${@:1:$#-1}")
    TARGET_ROOT="${@: -1}"
elif [ "$#" -le "3" ] && [ -d "${1:-}" ] &&
    { [ "$#" -eq "1" ] || [ -d "${@: -1}" ]; }; then
    SOURCE_ROOT="$(realpath "$1")"
    [ "$#" -eq "1" ] || TARGET_ROOT="${@: -1}"
    [ "$#" -lt "3" ] || SOURCE_EXT="${2#.}"
    SOURCE_FILES=()
    while IFS= read -rd $'\0' SOURCE_FILE; do
        SOURCE_FILES+=("$SOURCE_FILE")
    done < <(find "$SOURCE_ROOT" -type f ! -name ".*" -iname "*.${SOURCE_EXT:-mkv}" -print0 | sort -z)
else
    SOURCE_FILES=()
fi

[ "${#SOURCE_FILES[@]}" -gt "0" ] ||
    die "\
Usage:
  $(basename "$0") source_file... [target_dir]
  $(basename "$0") source_dir [[source_ext] target_dir]"

TARGET_ROOT="${TARGET_ROOT:-${HANDBRAKE_TARGET:-$PWD}}"
[ -d "$TARGET_ROOT" ] || mkdir -pv "$TARGET_ROOT" || die "unable to create directory '$TARGET_ROOT'"
TARGET_EXT="${HANDBRAKE_TARGET_EXT:-m4v}"
TARGET_EXT="${TARGET_EXT#.}"
TARGET_FILES=()
HANDBRAKE_PRESET="${HANDBRAKE_PRESET:-General/HQ 1080p30 Surround}"
ENCODE_LIST=()

for SOURCE_FILE in "${SOURCE_FILES[@]}"; do
    TARGET_SUBFOLDER=
    if [ -n "${SOURCE_ROOT:-}" ]; then
        TARGET_SUBFOLDER="$(dirname "$SOURCE_FILE")"
        TARGET_SUBFOLDER="${TARGET_SUBFOLDER#$SOURCE_ROOT}"
    fi
    TARGET_FILE="$TARGET_ROOT$TARGET_SUBFOLDER/$(basename "${SOURCE_FILE%.*}.$TARGET_EXT")"
    if [ -e "$TARGET_FILE" ]; then
        lk_console_warning "Skipping '$SOURCE_FILE' because '$TARGET_FILE' already exists"
        TARGET_FILE=""
    else
        ENCODE_LIST+=("$SOURCE_FILE -> $TARGET_FILE")
    fi
    TARGET_FILES+=("$TARGET_FILE")
done

lk_echo_array "${ENCODE_LIST[@]}" | lk_console_list "Ready for encoding:" "file" "files"
lk_confirm "Proceed using $BOLD$HANDBRAKE_PRESET$RESET preset?" Y
SUCCESS_FILES=()
ERROR_FILES=()

{
    for i in "${!SOURCE_FILES[@]}"; do
        [ ! -e "$HOME/.stop-handbrake-batch" ] || break
        SOURCE_FILE="${SOURCE_FILES[$i]}"
        TARGET_FILE="${TARGET_FILES[$i]}"
        [ -n "$TARGET_FILE" ] || continue
        TARGET_DIR="$(dirname "$TARGET_FILE")"
        [ -d "$TARGET_DIR" ] || mkdir -pv "$TARGET_DIR" || die "unable to create directory '$TARGET_DIR'"
        LOG_FILE="${SOURCE_FILE%/*}/.${SOURCE_FILE##*/}-HandBrakeCLI.log"
        EXIT_CODE=0
        if ! HandBrakeCLI --preset-import-gui --preset "$HANDBRAKE_PRESET" --input "$SOURCE_FILE" --output "$TARGET_FILE" 2> >(tee "$LOG_FILE" >&2); then
            EXIT_CODE="$?"
            ERROR_FILES+=("$TARGET_FILE")
        else
            SUCCESS_FILES+=("$TARGET_FILE")
        fi
        echo "$(lk_date_log) HandBrakeCLI exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
    done

    [ "${#SUCCESS_FILES[@]}" -eq "0" ] ||
        lk_echo_array "${SUCCESS_FILES[@]}" | lk_console_list "Encoded successfully:" "file" "files" "$BOLD$GREEN"
    [ "${#ERROR_FILES[@]}" -eq "0" ] ||
        lk_echo_array "${ERROR_FILES[@]}" | lk_console_list "Errors encountered during encoding:" "file" "files" "$BOLD$RED"

    rm -f "$HOME/.stop-handbrake-batch"

    [ "${#ERROR_FILES[@]}" -eq "0" ]
    exit
}
