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

synergy_kill

echo "[ $(date '+%+') ] Starting: $SYNERGY_COMMAND -f --no-tray -d INFO -l $LOG_FILE -n $1 $2" >>"$LOG_FILE2"

set +e
"$SYNERGY_COMMAND" -f --no-tray -d INFO -l "$LOG_FILE" -n "$1" "$2" >>"$LOG_FILE2" 2>&1
RESULT="$?"
set -e

echo "[ $(date '+%+') ] Exited with code: $RESULT" >>"$LOG_FILE2"
exit $RESULT
