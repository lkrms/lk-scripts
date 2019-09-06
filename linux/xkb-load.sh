#!/bin/bash

# Recommended:
# - create file: config/xkbcomp (an example is provided)
# - rely on xrandr-auto.sh during startup and/or via keyboard shortcut

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_not_root
assert_command_exists xkbcomp

# give it a second for keys to be (physically) released
has_argument "--no-sleep" || sleep 1

if [ -f "$CONFIG_DIR/xkbcomp" ] && [ -n "$DISPLAY" ]; then

    echo -e "xkbcomp -I$SCRIPT_DIR/xkb $CONFIG_DIR/xkbcomp $DISPLAY\n" >&2
    xkbcomp -I"$SCRIPT_DIR/xkb" "$CONFIG_DIR/xkbcomp" "$DISPLAY"

fi

if ! has_argument "--autostart"; then

    if command_exists systemctl && systemctl --user --quiet is-active sxhkd.service; then

        echo -e "systemctl --user restart sxhkd.service\n" >&2
        systemctl --user restart sxhkd.service

    fi

fi
