#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_not_root
assert_command_exists xinput

function xinput_set_prop() {

    if xinput list-props "$1" | grep "$2" >/dev/null; then

        echo -e "xinput set-prop $*\n" >&2
        xinput set-prop "$@" || die "Error: unable to set '$2' on device $1"

    else

        return 1

    fi

}

function xinput_set_sign() {

    local VALUES VALUE SIGNED=()

    # shellcheck disable=SC2207
    if VALUES=($(
        # shellcheck disable=SC1090
        . "$SUBSHELL_SCRIPT_PATH" || exit
        xinput list-props "$1" | grep -E "$2"'\s+\([0-9]+\):\s+((,\s*)?-?[0-9]+)+\s*$' | head -n1 | grep -Eo '((,\s*)?-?[0-9]+)+\s*$' | grep -Eo '[0-9]+'
    )); then

        for VALUE in "${VALUES[@]}"; do

            ((VALUE = VALUE * $3)) || true
            SIGNED+=("$VALUE")

        done

        echo -e "xinput set-prop $1 $2 ${SIGNED[*]}\n" >&2
        xinput set-prop "$1" "$2" "${SIGNED[@]}" || die "Error: unable to set '$2' on device $1"

    else

        return 1

    fi

}

file_to_array "$CONFIG_DIR/natural-scroll-devices" '^[[:space:]]*$' '^#'

if [ "${#FILE_TO_ARRAY[@]}" -gt "0" ]; then

    LINES="$(xinput list | grep -E '\bslave\s+pointer\b')"
    MATCHING_LINES=()

    for PATTERN in "${FILE_TO_ARRAY[@]}"; do

        MATCHING_LINES+=("$(grep -E "$PATTERN" <<<"$LINES")")

    done

    if [ "${#MATCHING_LINES[@]}" -gt "0" ]; then

        # shellcheck disable=SC2207
        DEVICE_IDS=($(printf '%s\n' "${MATCHING_LINES[@]}" | sort | uniq | gnu_grep -Po '(?<=\bid=)[0-9]+\b'))

        if [ "${#DEVICE_IDS[@]}" -gt "0" ]; then

            for DEVICE_ID in "${DEVICE_IDS[@]}"; do

                xinput_set_prop "$DEVICE_ID" 'libinput Natural Scrolling Enabled' 1 ||
                    xinput_set_prop "$DEVICE_ID" 'Evdev Scrolling Distance' -1 -1 -1 ||
                    xinput_set_sign "$DEVICE_ID" 'Synaptics Scrolling Distance' -1 ||
                    true

            done

        fi

    fi

fi

file_to_array "$CONFIG_DIR/xinput-settings" '^[[:space:]]*$' '^#'

if [ "${#FILE_TO_ARRAY[@]}" -gt "0" ]; then

    # each setting is a two-line tuple: regex, then setting
    for ((i = 0; i < ${#FILE_TO_ARRAY[@]}; i++)); do

        PATTERN="${FILE_TO_ARRAY[$i]}"

        ((++i))
        ((i < ${#FILE_TO_ARRAY[@]})) || {
            ((PATTERN_ID = (i + 1) / 2))
            echo -e "Error: no setting for pattern $PATTERN_ID in $FILE_TO_ARRAY_FILENAME\n" >&2
            break
        }

        SETTING="${FILE_TO_ARRAY[$i]}"

        LINES=("$(xinput list | grep -E "$PATTERN")")
        DEVICE_IDS=($(printf '%s\n' "${LINES[@]}" | sort | uniq | gnu_grep -Po '(?<=\bid=)[0-9]+\b'))

        if [ "${#DEVICE_IDS[@]}" -gt "0" ]; then

            for DEVICE_ID in "${DEVICE_IDS[@]}"; do

                eval xinput_set_prop "$DEVICE_ID" "$SETTING" || true

            done

        fi

    done

fi
