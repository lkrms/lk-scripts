#!/bin/bash
# shellcheck disable=SC1090

include='' . lk-bash-load.sh || exit

[ "$#" -gt "0" ] || lk_die "Usage: $(basename "$0") function_name [argument1...]"

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
        lk_command_exists apt-get || continue
        ;;

    esac

    lk_console_item "Sourcing:" "$COMMON" "$CYAN" >&2
    . "$COMMON"

done

declare -F "$1" >/dev/null 2>&1 || lk_die "Function not defined: $1"

eval "$@"
