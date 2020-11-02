#!/bin/bash
# shellcheck disable=SC1090

include='' . lk-bash-load.sh || exit

lk_assert_command_exists xinput

function xinput_is_touchpad() {

    xinput_has_prop "$1" "Synaptics Capabilities"

}

function xinput_has_prop() {

    xinput list-props "$1" | grep "$2" >/dev/null

}

function xinput_set_prop() {

    if xinput_has_prop "$1" "$2"; then

        xinput set-prop "$@" || lk_die "Error: unable to set '$2' on device $1"

    else

        return 1

    fi

}

function xinput_set_sign() {

    local VALUES VALUE SIGNED=()

    # shellcheck disable=SC2207
    if VALUES=($(
        xinput list-props "$1" | grep -E "$2"'\s+\([0-9]+\):\s+((,\s*)?-?[0-9]+)+\s*$' | head -n1 | grep -Eo '((,\s*)?-?[0-9]+)+\s*$' | grep -Eo '[0-9]+'
    )); then

        for VALUE in "${VALUES[@]}"; do

            ((VALUE = VALUE * $3)) || true
            SIGNED+=("$VALUE")

        done

        xinput set-prop "$1" "$2" "${SIGNED[@]}" || lk_die "Error: unable to set '$2' on device $1"

    else

        return 1

    fi

}

lk_mapfile "$CONFIG_DIR/natural-scroll-devices" FILE_TO_ARRAY "^([[:blank:]]*\$|[#;])"

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

lk_mapfile "$CONFIG_DIR/xinput-settings" FILE_TO_ARRAY "^([[:blank:]]*\$|[#;])"

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

        LINES=("$(xinput list | grep -E "$PATTERN")") || continue
        DEVICE_IDS=($(printf '%s\n' "${LINES[@]}" | sort | uniq | gnu_grep -Po '(?<=\bid=)[0-9]+\b'))

        if [ "${#DEVICE_IDS[@]}" -gt "0" ]; then

            for DEVICE_ID in "${DEVICE_IDS[@]}"; do

                eval xinput_set_prop "$DEVICE_ID" "$SETTING" || true

            done

        fi

    done

fi

if [ "${XINPUT_DISABLE_TOUCHPAD_DURATION:-0.5}" != "0" ] && lk_command_exists syndaemon; then

    DEVICE_IDS=($(xinput list | grep -E '\bslave\s+pointer\b' | sort | uniq | gnu_grep -Po '(?<=\bid=)[0-9]+\b'))
    HAVE_TOUCHPAD=0

    if [ "${#DEVICE_IDS[@]}" -gt "0" ]; then

        for DEVICE_ID in "${DEVICE_IDS[@]}"; do

            ! xinput_is_touchpad "$DEVICE_ID" || {
                HAVE_TOUCHPAD=1
                break
            }

        done

        [ "$HAVE_TOUCHPAD" -eq "0" ] || {

            killall syndaemon 2>/dev/null || true

            syndaemon -i "${XINPUT_DISABLE_TOUCHPAD_DURATION:-0.5}" -d -t -K -R

        }

    fi

fi
