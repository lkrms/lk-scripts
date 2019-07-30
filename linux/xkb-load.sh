#!/bin/bash

# Recommended:
# - create ../config/xkbcomp
# - bind a keyboard shortcut (e.g. Ctrl+Alt+K) to "/path/to/linux/xkb-load.sh"
# - rely on "/path/to/linux/xrandr-auto.sh --autostart" during startup

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

IS_AUTOSTART=0
[ "${1:-}" = "--autostart" ] && IS_AUTOSTART=1 || true

if command_exists xkbcomp && [ -e "$CONFIG_DIR/xkbcomp" ] && [ -n "$DISPLAY" ]; then

    sleep 1

    xkbcomp "$CONFIG_DIR/xkbcomp" "$DISPLAY"

fi

if [ "$IS_AUTOSTART" -eq "0" ]; then

    if command_exists systemctl && systemctl --user --quiet is-active sxhkd.service; then

        systemctl --user restart --no-block sxhkd.service

    fi

fi
