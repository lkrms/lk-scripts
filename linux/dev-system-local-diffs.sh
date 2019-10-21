#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

LOCAL_PATHS=(
    "$HOME/.config/autostart"
    "$HOME/.local/share/applications"
    "$HOME/.themes"
)

SYSTEM_PATHS=(
    "/etc/xdg/autostart"
    "/usr/share/applications"
    "/usr/share/themes"
)

SYSTEM_FAILOVER_PATHS=(
    "/usr/share/applications"
    ""
    ""
)

CONDITIONS=(
    ""
    "-iname *.desktop"
    ""
)

NO_SYSTEM=()
FAILOVER=()

for i in "${!LOCAL_PATHS[@]}"; do

    LOCAL_PATH="${LOCAL_PATHS[$i]}"
    SYSTEM_PATH="${SYSTEM_PATHS[$i]}"
    SYSTEM_FAILOVER_PATH="${SYSTEM_FAILOVER_PATHS[$i]}"

    if [ ! -d "$LOCAL_PATH" ] || [ ! -d "$SYSTEM_PATH" ]; then

        continue

    fi

    # disable globbing
    set -f
    # shellcheck disable=SC2206
    FIND_EXTRA=(${CONDITIONS[$i]})
    set +f

    pushd "$LOCAL_PATH" >/dev/null

    set +u

    while IFS= read -rd $'\0' FILENAME; do

        FILENAME="${FILENAME##./}"

        if [ -e "$SYSTEM_PATH/$FILENAME" ]; then

            diff -sU 5 --color=always "$SYSTEM_PATH/$FILENAME" "$LOCAL_PATH/$FILENAME" || true
            echo

        elif [ -n "$SYSTEM_FAILOVER_PATH" ] && [ -e "$SYSTEM_FAILOVER_PATH/$FILENAME" ]; then

            diff -sU 5 --color=always "$SYSTEM_FAILOVER_PATH/$FILENAME" "$LOCAL_PATH/$FILENAME" || true
            echo

            FAILOVER+=("$LOCAL_PATH/$FILENAME")

        else

            NO_SYSTEM+=("$LOCAL_PATH/$FILENAME")

        fi

    done < <(find . -type f "${FIND_EXTRA[@]}" -print0 | sort -z)

    set -u

    popd >/dev/null

done

if [ "${#FAILOVER[@]}" -gt "0" ]; then

    echoc "Local $(single_or_plural "${#FAILOVER[@]}" file files) with system failover $(single_or_plural "${#FAILOVER[@]}" counterpart counterparts):" "$BOLD"

    printf '%s\n' "${FAILOVER[@]}"
    echo

fi

if [ "${#NO_SYSTEM[@]}" -gt "0" ]; then

    echoc "Local $(single_or_plural "${#NO_SYSTEM[@]}" file files) with no system $(single_or_plural "${#NO_SYSTEM[@]}" counterpart counterparts):" "$BOLD"

    printf '%s\n' "${NO_SYSTEM[@]}"
    echo

fi
