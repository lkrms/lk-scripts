#!/bin/bash
# shellcheck disable=SC1091

include='' . lk-bash-load.sh || exit

# shellcheck disable=SC2034
LK_USAGE="\
Usage: ${0##*/} <SOURCE_FILE>... [<TARGET_DIR>]
   or: ${0##*/} <SOURCE_DIR> [[<SOURCE_EXT>] <TARGET_DIR>]"

if lk_files_exist "$@"; then
    # <SOURCE_FILE>...
    SOURCE_FILES=("$@")
elif [ "$#" -gt "1" ] && lk_files_exist "${@:1:$#-1}" && [ -d "${*: -1}" ]; then
    # <SOURCE_FILE>... <TARGET_DIR>
    SOURCE_FILES=("${@:1:$#-1}")
    TARGET_ROOT="${*: -1}"
elif [ "$#" -le "3" ] && [ -d "${1:-}" ] &&
    { [ "$#" -eq "1" ] || [ -d "${*: -1}" ]; }; then
    # <SOURCE_DIR>
    SOURCE_ROOT="$(realpath "$1")"
    SOURCE_PREFIX="${SOURCE_ROOT%/*}"
    # <SOURCE_DIR> [<SOURCE_EXT>] <TARGET_DIR>
    [ "$#" -eq "1" ] || TARGET_ROOT="${*: -1}"
    [ "$#" -lt "3" ] || SOURCE_EXT="${2#.}"
    SOURCE_FILES=()
    while IFS= read -rd $'\0' SOURCE_FILE; do
        SOURCE_FILES+=("$SOURCE_FILE")
    done < <(
        find "$SOURCE_ROOT" \
            -type f ! -name ".*" -iname "*.${SOURCE_EXT:-mkv}" -print0 |
            sort -z
    )
else
    SOURCE_FILES=()
fi

lk_check_args
[ "${#SOURCE_FILES[@]}" -gt "0" ] || lk_usage

TARGET_ROOT="${TARGET_ROOT:-${HANDBRAKE_TARGET:-$PWD}}"
TARGET_ROOT="${TARGET_ROOT%/}"
[ -d "$TARGET_ROOT" ] || mkdir -pv "$TARGET_ROOT" ||
    lk_die "unable to create directory '$TARGET_ROOT'"
TARGET_EXT="${HANDBRAKE_TARGET_EXT:-m4v}"
TARGET_EXT="${TARGET_EXT#.}"
TARGET_FILES=()
HANDBRAKE_PRESET="${HANDBRAKE_PRESET:-General/HQ 1080p30 Surround}"
ENCODE_LIST=()

lk_console_message "Preparing batch"
for SOURCE_FILE in "${SOURCE_FILES[@]}"; do
    TARGET_SUBFOLDER=
    if [ -n "${SOURCE_ROOT:-}" ]; then
        TARGET_SUBFOLDER="${SOURCE_FILE%/*}"
        TARGET_SUBFOLDER="${TARGET_SUBFOLDER#$SOURCE_PREFIX}"
    fi
    TARGET_FILE="$TARGET_ROOT$TARGET_SUBFOLDER/${SOURCE_FILE##*/}"
    TARGET_FILE="${TARGET_FILE%.*}.$TARGET_EXT"
    if [ -e "$TARGET_FILE" ]; then
        lk_console_warning "Skipping (target already exists):" "$SOURCE_FILE"
        TARGET_FILE=""
    else
        ENCODE_LIST+=("$SOURCE_FILE -> $TARGET_FILE")
    fi
    TARGET_FILES+=("$TARGET_FILE")
done

[ "${#ENCODE_LIST[@]}" -gt "0" ] ||
    lk_die "nothing to encode"

lk_echo_array ENCODE_LIST |
    LK_CONSOLE_SECONDARY_COLOUR="$LK_CONSOLE_COLOUR" \
        lk_console_detail_list "Queued:" "encode" "encodes"
lk_console_detail "HandBrake preset:" "$HANDBRAKE_PRESET"
lk_confirm "Proceed?" Y || lk_die

SUCCESS_FILES=()
ERROR_FILES=()

{
    for i in "${!SOURCE_FILES[@]}"; do
        [ ! -e "$HOME/.stop-handbrake-batch" ] || break
        SOURCE_FILE="${SOURCE_FILES[$i]}"
        TARGET_FILE="${TARGET_FILES[$i]}"
        [ -n "$TARGET_FILE" ] || continue
        TARGET_DIR="${TARGET_FILE%/*}"
        [ -d "$TARGET_DIR" ] || mkdir -pv "$TARGET_DIR" ||
            lk_die "unable to create directory '$TARGET_DIR'"
        LOG_FILE="${SOURCE_FILE%/*}/.${SOURCE_FILE##*/}-HandBrakeCLI.log"
        EXIT_CODE=0
        if ! HandBrakeCLI --preset-import-gui --preset "$HANDBRAKE_PRESET" \
            --input "$SOURCE_FILE" --output "$TARGET_FILE" \
            2> >(tee "$LOG_FILE" >&2); then
            EXIT_CODE="$?"
            ERROR_FILES+=("$SOURCE_FILE")
        else
            SUCCESS_FILES+=("$SOURCE_FILE")
        fi
        echo "$(lk_date_log) HandBrakeCLI exit code: $EXIT_CODE" |
            tee -a "$LOG_FILE"
    done

    [ "${#SUCCESS_FILES[@]}" -eq "0" ] ||
        lk_echo_array SUCCESS_FILES |
        lk_console_list "Encoded successfully:" "file" "files" "$LK_GREEN"
    [ "${#ERROR_FILES[@]}" -eq "0" ] ||
        lk_echo_array ERROR_FILES |
        lk_console_list "Failed to encode:" "file" "files" "$LK_RED"

    rm -f "$HOME/.stop-handbrake-batch"

    [ "${#ERROR_FILES[@]}" -eq "0" ]
    exit
}
