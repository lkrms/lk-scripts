#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-synergy
. "$SCRIPT_DIR/../bash/common-synergy"

if [ "$#" -ne "2" ]; then

    die "Usage: $(basename "$0") <my-host-name> <synergy-server>"

fi

SYNERGY_COMMAND="$(synergy_find_executable synergyc)"

synergy_get_log_files synergyc

COMMAND_LINE=("$SYNERGY_COMMAND" --no-tray -d INFO -n "$1")

if [ "$EUID" -ne "0" ]; then

    COMMAND_LINE+=(-f)

    if [ "$IS_LINUX" -eq "1" ] && [ -d "/etc/lightdm/lightdm.conf.d" ]; then

        IFS= read -rd '' LIGHTDM_CONF <<EOF || true
[SeatDefaults]
greeter-setup-script="$SCRIPT_DIR/$(basename "$SCRIPT_PATH")" "$1" "$2"
EOF

        if [ ! -e "/etc/lightdm/lightdm.conf.d/synergy.conf" ] || ! diff -bq "/etc/lightdm/lightdm.conf.d/synergy.conf" <(echo "$LIGHTDM_CONF") >/dev/null; then

            echo "$LIGHTDM_CONF" | sudo tee "/etc/lightdm/lightdm.conf.d/synergy.conf" >/dev/null

        fi

    fi

fi

COMMAND_LINE+=("$2")

while :; do

    synergy_kill

    echo "[ $(date '+%c') ] Starting: ${COMMAND_LINE[*]}" >>"$LOG_FILE2"

    RESULT=0
    "${COMMAND_LINE[@]}" >>"$LOG_FILE2" 2>&1 || RESULT="$?"

    echo "[ $(date '+%c') ] Exited with code: $RESULT" >>"$LOG_FILE2"

    if [ "$EUID" -ne "0" ] && [ "$IS_LINUX" -eq "1" ] && command_exists gdbus; then

        echo "[ $(date '+%c') ] Waiting for session unlock" >>"$LOG_FILE2"

        while IFS= read -r LINE; do

            if [[ "$LINE" == *org.freedesktop.login1.Session.Unlock* ]]; then

                break

            fi

        done < <(gdbus monitor --system --dest org.freedesktop.login1 --object-path "/org/freedesktop/login1/session/$XDG_SESSION_ID")

        # gdbus will keep running forever otherwise (not even SIGPIPE kills it)
        if SUBSHELL_PID="$(pgrep -P $$)"; then

            pkill -xP "$SUBSHELL_PID" gdbus || true

        fi

        echo "[ $(date '+%c') ] Session unlock detected; restarting" >>"$LOG_FILE2"

    else

        exit $RESULT

    fi

done
