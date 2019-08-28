#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_command_exists xfconf-query

[ -n "${1:-}" ] || die "Usage: $(basename "$0") <effective dpi>"

case "$1" in

# 2x
192)
    _16=32
    _24=48
    _32=64
    _48=96
    ;;

# 1.5x
144)
    _16=24
    _24=36
    _32=48
    _48=72
    ;;

# 1x
*)
    _16=16
    _24=24
    _32=32
    _48=48
    ;;

esac

# mouse cursor size
xfconf-query -c xsettings -p "/Gtk/CursorThemeSize" -n -t int -s "${_24}"

xfconf-query -c xsettings -p "/Gtk/IconSizes" -n -t string -s "gtk-button=${_16},${_16}:gtk-dialog=${_48},${_48}:gtk-dnd=${_32},${_32}:gtk-large-toolbar=${_24},${_24}:gtk-menu=${_16},${_16}:gtk-small-toolbar=${_16},${_16}"
