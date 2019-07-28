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

synergy_prepare_command_line

COMMAND_LINE+=("$SYNERGY_COMMAND" --no-tray -d INFO -n "$1")

case "$(basename "$0")" in

*daemon*)
    IS_DAEMON=1
    ;;

*)
    COMMAND_LINE+=(-f)
    IS_DAEMON=0
    ;;

esac

COMMAND_LINE+=("$2")

while :; do

    synergy_kill

    echo "[ $(date '+%c') ] Starting: ${COMMAND_LINE[*]}" >>"$LOG_FILE2"

    RESULT=0
    "${COMMAND_LINE[@]}" >>"$LOG_FILE2" 2>&1 || RESULT="$?"

    # restart on unlock if running in the foreground without root privileges
    if [ "$EUID" -ne "0" ] && [ "$IS_DAEMON" -eq "0" ] && [ "$IS_LINUX" -eq "1" ] && command_exists gdbus; then

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
