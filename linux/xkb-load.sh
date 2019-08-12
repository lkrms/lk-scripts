#!/bin/bash

# Recommended:
# - create ../config/xkbcomp
# - rely on "/path/to/linux/xrandr-auto.sh" during startup and/or via keyboard shortcut

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_not_root
assert_command_exists xkbcomp

has_argument "--autostart" && IS_AUTOSTART=1 || IS_AUTOSTART=0

if [ -e "$CONFIG_DIR/xkbcomp" ] && [ -n "$DISPLAY" ]; then

    xkbcomp "$CONFIG_DIR/xkbcomp" "$DISPLAY"

fi

if [ "$IS_AUTOSTART" -eq "0" ]; then

    if command_exists systemctl && systemctl --user --quiet is-active sxhkd.service; then

        systemctl --user reload sxhkd.service

    fi

fi
