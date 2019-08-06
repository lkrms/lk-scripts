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

synergy_get_log_file synergys

synergy_prepare_command_line

COMMAND_LINE+=("$SYNERGY_COMMAND" --no-tray -d INFO --enable-drag-drop -n "$1" -c "$2")

synergy_daemon_check

if [ -n "${3:-}" ]; then

    COMMAND_LINE+=(-a "$3")

fi

synergy_loop
