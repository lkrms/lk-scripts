#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../../bash/common
. "$SCRIPT_DIR/../../bash/common"

# shellcheck source=../../bash/common-apt
. "$SCRIPT_DIR/../../bash/common-apt"

assert_not_root

case "$(basename "$0")" in

*update*)
    apt_upgrade_all
    apt_purge --no-y
    ;;

*purge*)
    apt_purge --no-y
    ;;

esac