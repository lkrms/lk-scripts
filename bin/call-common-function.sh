#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

[ "$#" -gt "0" ] || die "Usage: $(basename "$0") function_name [argument1...]"

for COMMON in "$LK_ROOT/bash/common-"*; do

    case "$COMMON" in

    # already sourced if supported
    *-linux | *-macos | *-wsl)
        continue
        ;;

    # sourced in common-dev
    *-git)
        continue
        ;;

    *-apt)
        command_exists apt-get || continue
        ;;

    esac

    console_message "Sourcing:" "$COMMON" "$CYAN" >&2
    . "$COMMON"

done

declare -F "$1" >/dev/null 2>&1 || die "Function not defined: $1"

eval "$@"
