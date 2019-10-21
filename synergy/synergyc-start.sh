#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
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
