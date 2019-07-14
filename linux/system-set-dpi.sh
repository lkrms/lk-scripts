#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

if [ "$#" -ne "2" ] || ! is_int "${1:-}" || ! is_int "${2:-}"; then

    die "Usage: $(basename "$0") <scaling-factor> <dpi>"

fi

SCALING_FACTOR="$1"
DPI="$2"

let XFT_DPI=1024*DPI

if command_exists gsettings; then

    gsettings set org.gnome.settings-daemon.plugins.xsettings overrides "{'Gtk/DialogsUseHeader': <0>, 'Gtk/EnablePrimaryPaste': <0>, 'Gtk/ShellShowsAppMenu': <0>, 'Gtk/DecorationLayout': <'close:menu,maximize'>, 'Gdk/WindowScalingFactor': <$SCALING_FACTOR>, 'Xft/DPI': <$XFT_DPI>}" || true
    gsettings set org.gnome.desktop.interface scaling-factor "$SCALING_FACTOR" || true

fi

XSESSIONRC="$HOME/.xsessionrc"

if [ ! -e "$XSESSIONRC" ]; then

    touch "$XSESSIONRC"

fi

if ! grep -q QT_AUTO_SCREEN_SCALE_FACTOR "$XSESSIONRC"; then

    echo 'export QT_AUTO_SCREEN_SCALE_FACTOR=1' >>"$XSESSIONRC"

fi

if command_exists xrandr; then

    xrandr --dpi "$DPI"

    RC_CONTENT=$(grep -Ev '^xrandr --dpi [0-9]+$' "$XSESSIONRC")
    echo "$RC_CONTENT" >"$XSESSIONRC"
    echo "xrandr --dpi $DPI" >>"$XSESSIONRC"

fi
