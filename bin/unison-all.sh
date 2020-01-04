#!/bin/bash
# shellcheck disable=SC1090,SC2034
# Reviewed: 2020-01-04

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

[ "$#" -eq "0" ] || {
    DRYRUN_BY_DEFAULT=Y
    dryrun_message
}

shopt -s nullglob

case "$PLATFORM" in

linux | wsl)
    UNISON_ROOT="$HOME/.unison"
    ;;

mac)
    UNISON_ROOT="$HOME/Library/Application Support/Unison"
    ;;

*)
    die "$(basename "$0") is not supported on this platform"
    ;;

esac

UNISON_PROFILES=("$UNISON_ROOT/"*.prf)

[ "${#UNISON_PROFILES[@]}" -gt "0" ] || die "No Unison profiles found"

PROCESSED=()
FAILED=()
SKIPPED=()

for i in "${!UNISON_PROFILES[@]}"; do

    UNISON_PROFILE="${UNISON_PROFILES[$i]}"
    UNISON_PROFILE="$(basename "${UNISON_PROFILE%.prf}")"
    LOCAL_DIR="$HOME/$(upper_first "$UNISON_PROFILE")"

    case "$UNISON_PROFILE" in

    temp)
        [ ! -d "${LOCAL_DIR}.local" ] || LOCAL_DIR="${LOCAL_DIR}.local"
        ;;

    esac

    [ -d "$LOCAL_DIR" ] || {
        SKIPPED+=("$UNISON_PROFILE")
        continue
    }

    [ "$i" -eq "0" ] || echo

    lc_console_message "Syncing local directory:" '~'"${LOCAL_DIR#$HOME}" "$CYAN"

    if maybe_dryrun unison "$UNISON_PROFILE" -root "$LOCAL_DIR" -auto -logfile "$UNISON_ROOT/unison.$(hostname -s | tr "[:upper:]" "[:lower:]").log" "$@"; then

        PROCESSED+=("$UNISON_PROFILE")

    else

        FAILED+=("$UNISON_PROFILE($?)")

    fi

done

[ "${#SKIPPED[@]}" -eq "0" ] || {
    echo
    lc_echo_array "${SKIPPED[@]}" | lc_console_list "${#SKIPPED[@]} $(single_or_plural "${#SKIPPED[@]}" profile profiles) skipped:"
}

[ "${#PROCESSED[@]}" -eq "0" ] || {
    echo
    lc_echo_array "${PROCESSED[@]}" | lc_console_list "${#PROCESSED[@]} $(single_or_plural "${#PROCESSED[@]}" profile profiles) synchronised:" "$BOLD$GREEN"
}

[ "${#FAILED[@]}" -eq "0" ] || {
    echo
    lc_echo_array "${FAILED[@]}" | lc_console_list "${#FAILED[@]} $(single_or_plural "${#FAILED[@]}" profile profiles) failed:" "$BOLD$RED"
    echo
    pause
    exit 1
}
