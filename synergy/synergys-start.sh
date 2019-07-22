#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-synergy
. "$SCRIPT_DIR/../bash/common-synergy"

if [ "$#" -lt "2" ]; then

    die "Usage: $(basename "$0") <my-host-name> </path/to/config/file> [ip.address.to.listen.on]"

fi

SYNERGY_COMMAND="$(synergy_find_executable synergys)"

synergy_get_log_files synergys

synergy_kill

COMMAND_LINE=("$SYNERGY_COMMAND" -f --no-tray -d INFO --enable-drag-drop -n "$1" -c "$2")

if [ -n "${3:-}" ]; then

    COMMAND_LINE+=(-a "$3")

fi

echo "[ $(date '+%+') ] Starting: ${COMMAND_LINE[*]}" >>"$LOG_FILE2"

set +e
QT_BEARER_POLL_TIMEOUT=-1 "${COMMAND_LINE[@]}" >>"$LOG_FILE2" 2>&1
RESULT="$?"
set -e

echo "[ $(date '+%+') ] Exited with code: $RESULT" >>"$LOG_FILE2"
exit $RESULT
