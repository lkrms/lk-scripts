#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

is_macos || assert_command_exists xdg-open
! is_macos || assert_command_exists open

SCRATCHPAD_DIR="${SCRATCHPAD_DIR:-$HOME/Documents/Notes/Daily}"
TODAY_FILE="$SCRATCHPAD_DIR/$(date +'%Y-%m-%d').md"

mkdir -p "$SCRATCHPAD_DIR"

[ -e "$TODAY_FILE" ] || {

    printf "**Scratchpad for %s**\n\n\n" "$(date +'%A, %-d %B %Y')" >>"$TODAY_FILE"

}

is_macos || xdg-open "$TODAY_FILE"
! is_macos || open "$TODAY_FILE"
