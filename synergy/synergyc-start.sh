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

synergy_get_log_file synergyc

synergy_prepare_command_line

COMMAND_LINE+=("$SYNERGY_COMMAND" --no-tray -d INFO -n "$1")

synergy_daemon_check

COMMAND_LINE+=("$2")

synergy_loop
