#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=common
. "$SCRIPT_DIR/common"

[ "$#" -eq "1" ] || die "Usage: $(basename "$0") <uuid|vmname>"

VBoxManage modifyvm "$1" --autostart-enabled on --autostop-type savestate --defaultfrontend headless
