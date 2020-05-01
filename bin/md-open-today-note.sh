#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

is_macos && OPEN=open || OPEN=xdg-open
OPEN="${1:-$OPEN}"

assert_command_exists "$OPEN"

NOTES_DIR="${NOTES_DIR:-$HOME/Documents/Notes}"
TODAY_FILE="$NOTES_DIR/Daily/$(date +'%Y-%m-%d').md"

mkdir -p "$NOTES_DIR/Daily"

[ -e "$TODAY_FILE" ] || {

    printf "**Scratchpad for %s**\n\n\n" "$(date +'%A, %-d %B %Y')" >>"$TODAY_FILE"

}

"$OPEN" "$TODAY_FILE"
