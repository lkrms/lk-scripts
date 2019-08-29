#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=common
. "$SCRIPT_DIR/common"

# shellcheck source=common-dev
. "$SCRIPT_DIR/common-dev"

assert_not_root

if command_exists apt-get; then

    # shellcheck source=common-apt
    . "$SCRIPT_DIR/common-apt"

    apt_upgrade_all

fi
