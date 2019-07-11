#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/apt-common
. "$SCRIPT_DIR/../bash/apt-common"

assert_not_root

command_exists aptitude || apt_require_package "aptitude"

# https://www.debian.org/doc/manuals/aptitude/ch02s05s01.en.html#secDisplayFormat
FORMAT="%?p|%?v|%?O"

# https://www.debian.org/doc/manuals/aptitude/ch02s04s05.en.html
case "${1:-}" in

installed)
    aptitude search "?installed?not(?virtual)" -F "$FORMAT" | tee
    ;;

available)
    aptitude search "?not(?virtual)" -F "$FORMAT" | tee
    ;;

*)
    die "Usage: $(basename "$0") <installed|available>"
    ;;

esac
