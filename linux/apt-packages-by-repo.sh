#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/common-apt"

lk_assert_not_root

lk_assert_command_exists aptitude

# https://www.debian.org/doc/manuals/aptitude/ch02s05s01.en.html#secDisplayFormat
FORMAT="%?p|%?v|%?O"

# https://www.debian.org/doc/manuals/aptitude/ch02s04s05.en.html
case "${1-}" in

installed)
    aptitude search "?installed?not(?virtual)" -F "$FORMAT" | tee
    ;;

available)
    aptitude search "?not(?virtual)" -F "$FORMAT" | tee
    ;;

*)
    lk_die "Usage: $(basename "$0") <installed|available>"
    ;;

esac
