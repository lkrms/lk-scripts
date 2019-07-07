#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common"

if [ "$#" -ne "2" ]; then

    echo "Usage: $(basename "$0") <my-host-name> <synergy-server>" >&2
    exit 1

fi

# these are attempted in order
SYNERGY_COMMANDS=(synergyc /usr/bin/synergyc /usr/local/bin/synergyc /Applications/Synergy.app/Contents/MacOS/synergyc)
LOG_FILES=(/var/log/synergyc.log "$(dirname "$0")/synergyc.log" /tmp/synergyc.log)

SYNERGY_COMMAND=

for COMMAND in "${SYNERGY_COMMANDS[@]}"; do

    if command_exists "$COMMAND"; then

        SYNERGY_COMMAND="$COMMAND"
        break

    fi

done

if [ -z "$SYNERGY_COMMAND" ]; then

    echo "Error: unable to find synergyc command" >&2
    exit 1

fi

LOG_FILE=
LOG_FILE2=

for FILE in "${LOG_FILES[@]}"; do

    FILE2="${FILE%.log}.out.log"

    if [ -w "$FILE" -a -w "$FILE2" ]; then

        LOG_FILE="$FILE"

    elif [ -w "$(dirname "$FILE")" ]; then

        touch "$FILE" && touch "$FILE2" && LOG_FILE="$FILE" || true

    fi

    if [ -n "$LOG_FILE" ]; then

        LOG_FILE2="$FILE2"
        break

    fi

done

if [ -z "$LOG_FILE" ]; then

    echo "Error: unable to find a writable log file location" >&2
    exit 1

fi

if pgrep 'synergy.*' >/dev/null; then

    if [ "$EUID" -eq "0" ]; then

        pkill 'synergy.*'

    else

        pkill -u "$USER" 'synergy.*'

        sleep 1

        if pgrep 'synergy.*' >/dev/null; then

            sudo pkill 'synergy.*'

        fi

    fi

    sleep 1

    if pgrep 'synergy.*' >/dev/null; then

        echo "Error: synergy is already running" >&2
        exit 1

    fi

fi

echo "[ $(date '+%+') ] Starting: $SYNERGY_COMMAND -d INFO -l $LOG_FILE -n $1 $2" >>"$LOG_FILE2"

set +e
"$SYNERGY_COMMAND" -f -d INFO -l "$LOG_FILE" -n "$1" "$2" >>"$LOG_FILE2" 2>&1
RESULT="$?"
set -e

echo "[ $(date '+%+') ] Exited with code: $RESULT" >>"$LOG_FILE2"
exit $RESULT
