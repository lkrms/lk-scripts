#!/bin/bash
# shellcheck disable=SC1090
# Reviewed: 2019-11-13

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

shopt -s nullglob

for DEVICE in $(printf '%s\n' /sys/bus/usb/drivers/usbhid/* | gnu_grep -Po '(?<=/)[-0-9\.]+(?=:[0-9\.]+$)' | sort | uniq); do

    PRODUCT="$(<"/sys/bus/usb/devices/$DEVICE/product")"
    CURRENT_STATUS="$(<"/sys/bus/usb/devices/$DEVICE/power/control")"

    case "$(basename "$0")" in

    *get*)

        [ "$CURRENT_STATUS" = "on" ] && CURRENT_STATUS="disabled" || CURRENT_STATUS="enabled"
        printf "Power management for ${BOLD}%s${RESET} is currently ${BOLD}%s${RESET}\n" "$PRODUCT" "$CURRENT_STATUS"
        ;;

    *disable*)

        [ "$CURRENT_STATUS" != "on" ] || {
            printf "Power management already disabled for ${BOLD}%s${RESET}\n" "$PRODUCT"
            continue
        }

        if sudo tee "/sys/bus/usb/devices/$DEVICE/power/control" >/dev/null <<<"on"; then

            printf "Power management disabled for ${BOLD}%s${RESET}\n" "$PRODUCT"

        else

            printf "Error disabling power management for ${BOLD}%s${RESET}\n" "$PRODUCT"

        fi
        ;;

    *enable*)

        [ "$CURRENT_STATUS" = "on" ] || {
            printf "Power management already enabled for ${BOLD}%s${RESET}\n" "$PRODUCT"
            continue
        }

        if sudo tee "/sys/bus/usb/devices/$DEVICE/power/control" >/dev/null <<<"auto"; then

            printf "Power management enabled for ${BOLD}%s${RESET}\n" "$PRODUCT"

        else

            printf "Error enabling power management for ${BOLD}%s${RESET}\n" "$PRODUCT"

        fi
        ;;

    esac

done
