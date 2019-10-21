#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
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
