#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=common
. "$SCRIPT_DIR/common"

[ "$#" -ge "1" ] && [ "$#" -le "3" ] || die "Usage: $(basename "$0") <uuid|vmname> [delay-seconds [acpishutdown|savestate|...]]"

VBoxManage modifyvm "$1" --autostart-enabled on --autostart-delay "${2:-0}" --autostop-type "${3:-acpishutdown}" --defaultfrontend headless || die
