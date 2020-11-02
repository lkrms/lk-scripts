#!/bin/bash
# shellcheck disable=SC1090

# Recommended:
# - create file: config/xkbcomp (an example is provided)
# - rely on xrandr-auto.sh during startup and/or via keyboard shortcut

include='' . lk-bash-load.sh || exit

lk_assert_command_exists xkbcomp

while [[ "${1:-}" =~ ^-- ]]; do

    shift

done

[ ! -f "$CONFIG_DIR/${1:-xkbcomp}" ] || [ -z "$DISPLAY" ] || {

    # give it a second for keys to be (physically) released
    lk_has_arg "--no-sleep" || sleep 1

    xkbcomp -I"$SCRIPT_DIR/xkb" "$CONFIG_DIR/${1:-xkbcomp}" "$DISPLAY"

}
