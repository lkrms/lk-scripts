#!/bin/bash
# shellcheck disable=SC2034,SC1090

include='' . lk-bash-load.sh || exit

DISPLAY_NAMES=(
    "LG 27\" 4K"
    "AOC 27\" 4K"
)

DISPLAY_EDIDS=(
    # LG 27" 4K
    00ffffffffffff001e6d067739ac0100041d0103803c2278ea3e31ae5047ac270c50542108007140818081c0a9c0d1c081000101010108e80030f2705a80b0588a0058542100001e04740030f2705a80b0588a0058542100001a000000fd00383d1e873c000a202020202020000000fc004c472048445220344b0a20202001f7020338714d9022201f1203040161605d5e5f230907076d030c001000b83c20006001020367d85dc401788003e30f0003e305c000e3060501023a801871382d40582c450058542100001e565e00a0a0a029503020350058542100001a000000ff003930344e54574733373632350a0000000000000000000000000000000000f3

    # AOC 27" 4K
    00ffffffffffff0005e39027182c0000041d0103803c22782a67a1a5554da2270e5054bfef00d1c0b30095008180814081c0010101014dd000a0f0703e803020350055502100001aa36600a0f0701f803020350055502100001a000000fc005532373930420a202020202020000000fd0017501ea03c000a2020202020200181020333f14c9004031f1301125d5e5f606123090707830100006d030c001000387820006001020367d85dc401788003e30f000c565e00a0a0a029503020350055502100001e023a801871382d40582c450055502100001e011d007251d01e206e28550055502100001e4d6c80a070703e8030203a0055502100001a000000004e
)

DISPLAY_0_SETTINGS=(
    # brightness (default 90)
    "0x10 90"
    # contrast (default 70)
    "0x12 70"
)

DISPLAY_1_SETTINGS=(
    # brightness (default 90)
    "0x10 60"
    # contrast (default 50)
    "0x12 50"
)

[ "${#DISPLAY_EDIDS[@]}" -gt "0" ] || lk_die "No DISPLAY_EDIDS"

DISPLAY_KEYS=("${!DISPLAY_EDIDS[@]}")
DISPLAYS=()

while [[ "${1-}" =~ ^[0-9]+$ ]]; do

    lk_in_array "$1" DISPLAY_KEYS || lk_die "Nothing at DISPLAY_EDIDS[$1]"
    DISPLAYS+=("$1")
    shift

done

[ "${#DISPLAYS[@]}" -gt "0" ] || DISPLAYS=("${DISPLAY_KEYS[@]}")

USAGE="Usage: $(basename "$0") [displaynumber ...] <command> [arg ...]
    Run ddcutil commands on configured displays.

    displaynumber:  Index of display in DISPLAY_EDIDS array.
                    If not provided, command will run on all displays.

    command:
        [factory-]reset
            Reset display to factory default settings.

        test-range <code> <first> <increment> <last> [delay]
            Apply a sequence of numbers as feature values.

        set-brightness <value>
            Set display brightness.

        test-brightness
            Equivalent to:
                test-range 0x10 <max-brightness> -10 0
"

[ "$#" -ge "1" ] || lk_die "$USAGE"
COMMAND="$1"
shift

DEFAULT_TEST_SLEEP="${DEFAULT_TEST_SLEEP:-4}"

for i in "${DISPLAYS[@]}"; do

    ARGS=("$@")
    DISPLAY_EDID="${DISPLAY_EDIDS[$i]}"
    DISPLAY_NAME="display $i (${DISPLAY_NAMES[$i]})"
    EXIT_CODE=0

    # ddcutil only considers first 128 bytes
    DISPLAY_EDID="${DISPLAY_EDID:0:256}"

    case "$COMMAND" in

    reset | factory-reset)
        lk_console_message "Resetting $DISPLAY_NAME to factory defaults"
        sudo ddcutil --edid "$DISPLAY_EDID" setvcp 0x04 1 || EXIT_CODE="$?"
        ;;

    set-brightness)
        [ "${#ARGS[@]}" -eq "1" ] || lk_die "$USAGE"
        lk_console_message "Setting brightness on $DISPLAY_NAME to ${ARGS[0]}"
        sudo ddcutil --edid "$DISPLAY_EDID" setvcp 0x10 "${ARGS[0]}" || EXIT_CODE="$?"
        echo "To make ${ARGS[0]} the default, use: setvcp 0x10 ${ARGS[0]}"
        ;;

    test-brightness)
        lk_console_message "Running brightness test on $DISPLAY_NAME"
        if ! RESULT=($(sudo ddcutil --edid "$DISPLAY_EDID" getvcp 0x10 | grep -Eo '\b[0-9]+\b' || exit "${PIPESTATUS[0]}")); then
            EXIT_CODE="$?"
        else
            [ "${#RESULT[@]}" -eq "2" ] || lk_die "Unable to retrieve current and maximum brightness"
            CURRENT="${RESULT[0]}"
            MAX="${RESULT[1]}"
            echo "Current brightness $CURRENT (maximum $MAX)"
            for v in $(seq "$MAX" "-10" "0"); do
                echo "Setting brightness to $v"
                sudo ddcutil --edid "$DISPLAY_EDID" setvcp 0x10 "$v" || {
                    EXIT_CODE="$?"
                    break
                }
                sleep "$DEFAULT_TEST_SLEEP"
            done
            [ "$EXIT_CODE" -ne "0" ] || {
                echo "Restoring brightness to $CURRENT"
                sudo ddcutil --edid "$DISPLAY_EDID" setvcp 0x10 "$CURRENT" || EXIT_CODE="$?"
                echo "To make $CURRENT the default, use: setvcp 0x10 $CURRENT"
            }
        fi
        ;;

    get)
        COMMAND=getvcp
        ;;&

    set)
        COMMAND=setvcp
        ;;&

    test-range)
        SEQ=($(seq "${ARGS[1]}" "${ARGS[2]}" "${ARGS[3]}" 2>/dev/null)) && [ "${#SEQ[@]}" -gt "0" ] || lk_die "$USAGE"
        TEST_SLEEP="${ARGS[4]:-$DEFAULT_TEST_SLEEP}"
        lk_echo_array "${SEQ[@]}" | lk_console_list "Applying range of values to feature ${ARGS[0]} on $DISPLAY_NAME at ${TEST_SLEEP}s intervals"
        for v in "${SEQ[@]}"; do
            echo "Setting feature ${ARGS[0]} value to $v"
            sudo ddcutil --edid "$DISPLAY_EDID" setvcp "${ARGS[0]}" "$v" || {
                EXIT_CODE="$?"
                break
            }
            [ "${SEQ[-1]}" -eq "$v" ] || sleep "$TEST_SLEEP"
        done
        ;;

    *)
        ARGS=("$COMMAND" "${ARGS[@]}")
        lk_console_message "Running ddcutil command \"${ARGS[*]}\" on $DISPLAY_NAME"
        sudo ddcutil --edid "$DISPLAY_EDID" "${ARGS[@]}" || EXIT_CODE="$?"
        ;;

    esac

    [ "$EXIT_CODE" -eq "0" ] || lk_echoc "ddcutil exit code: $EXIT_CODE" "$LK_BOLD" "$LK_RED"

done
