#!/bin/bash
# shellcheck disable=SC1090

# Recommended:
# - create file: config/xkbcomp (an example is provided)
# - rely on xrandr-auto.sh during startup and/or via keyboard shortcut

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_command_exists xkbcomp

# give it a second for keys to be (physically) released
has_argument "--no-sleep" || sleep 1

if [ -f "$CONFIG_DIR/xkbcomp" ] && [ -n "$DISPLAY" ]; then

    echo -e "xkbcomp -I$SCRIPT_DIR/xkb $CONFIG_DIR/xkbcomp $DISPLAY\n" >&2
    xkbcomp -I"$SCRIPT_DIR/xkb" "$CONFIG_DIR/xkbcomp" "$DISPLAY"

fi

if ! has_argument "--autostart"; then

    if user_service_running "sxhkd"; then

        echo -e "systemctl --user restart sxhkd.service\n" >&2
        systemctl --user restart sxhkd.service

    fi

fi
