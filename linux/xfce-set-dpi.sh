#!/bin/bash
# shellcheck disable=SC2034

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_command_exists xfce4-panel
assert_command_exists xfconf-query
assert_command_exists bc

[ -n "${1:-}" ] || die "Usage: $(basename "$0") <effective dpi>"

[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || die "Error: DBUS_SESSION_BUS_ADDRESS not set"

RESTART_PANEL=0

_MULTIPLIER="$(bc <<<"scale = 10; $1 / 96")"
_MULTIPLIERx10="$(bc <<<"scale = 10; v = $1 * 10 / 96; scale = 0; v / 1")"

_16="$(bc <<<"v = 16 * $_MULTIPLIER / 1; v - v % 2")"
_24="$(bc <<<"v = 24 * $_MULTIPLIER / 1; v - v % 2")"
_32="$(bc <<<"v = 32 * $_MULTIPLIER / 1; v - v % 2")"
_48="$(bc <<<"v = 48 * $_MULTIPLIER / 1; v - v % 2")"
_GAP="$(bc <<<"v = 4 * $_MULTIPLIER / 1 - 2; if (v < 2) v = 2; v - v % 2")"

if [ "$_MULTIPLIERx10" -le "10" ]; then

    # scaling <= 1
    _MULTIPLIER_APPROX=1

    THUNAR_ICON_SIZE_16="THUNAR_ICON_SIZE_SMALLEST"
    THUNAR_ICON_SIZE_24="THUNAR_ICON_SIZE_SMALLER"
    THUNAR_ICON_SIZE_32="THUNAR_ICON_SIZE_SMALL"
    THUNAR_ICON_SIZE_48="THUNAR_ICON_SIZE_NORMAL"
    THUNAR_ICON_SIZE_64="THUNAR_ICON_SIZE_LARGE"
    THUNAR_ZOOM_LEVEL_25="THUNAR_ZOOM_LEVEL_SMALLEST"
    THUNAR_ZOOM_LEVEL_38="THUNAR_ZOOM_LEVEL_SMALLER"
    THUNAR_ZOOM_LEVEL_50="THUNAR_ZOOM_LEVEL_SMALL"
    THUNAR_ZOOM_LEVEL_75="THUNAR_ZOOM_LEVEL_NORMAL"
    THUNAR_ZOOM_LEVEL_100="THUNAR_ZOOM_LEVEL_LARGE"

elif [ "$_MULTIPLIERx10" -le "15" ]; then

    # 1 < scaling <= 1.5
    _MULTIPLIER_APPROX=1.5

    THUNAR_ICON_SIZE_16="THUNAR_ICON_SIZE_SMALLER"
    THUNAR_ICON_SIZE_24="THUNAR_ICON_SIZE_SMALL"
    THUNAR_ICON_SIZE_32="THUNAR_ICON_SIZE_NORMAL"
    THUNAR_ICON_SIZE_48="THUNAR_ICON_SIZE_LARGE"
    THUNAR_ICON_SIZE_64="THUNAR_ICON_SIZE_LARGER"
    THUNAR_ZOOM_LEVEL_25="THUNAR_ZOOM_LEVEL_SMALLER"
    THUNAR_ZOOM_LEVEL_38="THUNAR_ZOOM_LEVEL_SMALL"
    THUNAR_ZOOM_LEVEL_50="THUNAR_ZOOM_LEVEL_NORMAL"
    THUNAR_ZOOM_LEVEL_75="THUNAR_ZOOM_LEVEL_LARGE"
    THUNAR_ZOOM_LEVEL_100="THUNAR_ZOOM_LEVEL_LARGER"

else

    # scaling > 1.5
    _MULTIPLIER_APPROX=2

    THUNAR_ICON_SIZE_16="THUNAR_ICON_SIZE_SMALL"
    THUNAR_ICON_SIZE_24="THUNAR_ICON_SIZE_NORMAL"
    THUNAR_ICON_SIZE_32="THUNAR_ICON_SIZE_LARGE"
    THUNAR_ICON_SIZE_48="THUNAR_ICON_SIZE_LARGER"
    THUNAR_ICON_SIZE_64="THUNAR_ICON_SIZE_LARGEST"
    THUNAR_ZOOM_LEVEL_25="THUNAR_ZOOM_LEVEL_SMALL"
    THUNAR_ZOOM_LEVEL_38="THUNAR_ZOOM_LEVEL_NORMAL"
    THUNAR_ZOOM_LEVEL_50="THUNAR_ZOOM_LEVEL_LARGE"
    THUNAR_ZOOM_LEVEL_75="THUNAR_ZOOM_LEVEL_LARGER"
    THUNAR_ZOOM_LEVEL_100="THUNAR_ZOOM_LEVEL_LARGEST"

fi

# disable Appearance > Fonts > Custom DPI setting
echo -e "xfconf-query -c xsettings -p /Xft/DPI -n -t int -s -1\n" >&2
xfconf-query -c "xsettings" -p "/Xft/DPI" -n -t int -s "-1"

# mouse cursor size
echo -e "xfconf-query -c xsettings -p /Gtk/CursorThemeSize -n -t int -s ${_24}\n" >&2
xfconf-query -c "xsettings" -p "/Gtk/CursorThemeSize" -n -t int -s "${_24}"

echo -e "xfconf-query -c xsettings -p /Gtk/IconSizes -n -t string -s gtk-button=${_16},${_16}:gtk-dialog=${_48},${_48}:gtk-dnd=${_32},${_32}:gtk-large-toolbar=${_24},${_24}:gtk-menu=${_16},${_16}:gtk-small-toolbar=${_16},${_16}\n" >&2
xfconf-query -c "xsettings" -p "/Gtk/IconSizes" -n -t string -s "gtk-button=${_16},${_16}:gtk-dialog=${_48},${_48}:gtk-dnd=${_32},${_32}:gtk-large-toolbar=${_24},${_24}:gtk-menu=${_16},${_16}:gtk-small-toolbar=${_16},${_16}"

echo -e "xfconf-query -c thunar -p /shortcuts-icon-size -n -t string -s $THUNAR_ICON_SIZE_24\n" >&2
xfconf-query -c "thunar" -p "/shortcuts-icon-size" -n -t string -s "$THUNAR_ICON_SIZE_24"

echo -e "xfconf-query -c thunar -p /tree-icon-size -n -t string -s $THUNAR_ICON_SIZE_32\n" >&2
xfconf-query -c "thunar" -p "/tree-icon-size" -n -t string -s "$THUNAR_ICON_SIZE_32"

echo -e "xfconf-query -c thunar -p /last-icon-view-zoom-level -n -t string -s $THUNAR_ZOOM_LEVEL_75\n" >&2
xfconf-query -c "thunar" -p "/last-icon-view-zoom-level" -n -t string -s "$THUNAR_ZOOM_LEVEL_75"

echo -e "xfconf-query -c thunar -p /last-details-view-zoom-level -n -t string -s $THUNAR_ZOOM_LEVEL_38\n" >&2
xfconf-query -c "thunar" -p "/last-details-view-zoom-level" -n -t string -s "$THUNAR_ZOOM_LEVEL_38"

echo -e "xfconf-query -c thunar -p /last-compact-view-zoom-level -n -t string -s $THUNAR_ZOOM_LEVEL_25\n" >&2
xfconf-query -c "thunar" -p "/last-compact-view-zoom-level" -n -t string -s "$THUNAR_ZOOM_LEVEL_25"

if PANELS="$(
    # shellcheck disable=SC1090
    . "$SUBSHELL_SCRIPT_PATH" || exit
    xfconf-query -c "xfce4-panel" -p "/panels" -lv 2>/dev/null | grep -Eo '^/panels/[^/]+/' | sort | uniq
)"; then

    while IFS= read -r PANEL; do

        # XFCE panel size
        echo -e "xfconf-query -c xfce4-panel -p ${PANEL}size -n -t int -s ${_24}\n" >&2
        xfconf-query -c "xfce4-panel" -p "${PANEL}size" -n -t int -s "${_24}"

    done < <(echo "$PANELS")

fi

if PANEL_PLUGINS="$(
    # shellcheck disable=SC1090
    . "$SUBSHELL_SCRIPT_PATH" || exit
    xfconf-query -c "xfce4-panel" -p "/plugins" -lv 2>/dev/null | grep -E '^/plugins/[^/]+\s+'
)"; then

    ((PANEL_ICON_SIZE = _24 - _GAP))

    while IFS=' ' read -r PLUGIN_ID PLUGIN_NAME; do

        case "$PLUGIN_NAME" in

        systray)
            echo -e "xfconf-query -c xfce4-panel -p ${PLUGIN_ID}/size-max -n -t int -s $PANEL_ICON_SIZE\n" >&2
            xfconf-query -c "xfce4-panel" -p "${PLUGIN_ID}/size-max" -n -t int -s "$PANEL_ICON_SIZE"
            ;;

        statusnotifier)
            echo -e "xfconf-query -c xfce4-panel -p ${PLUGIN_ID}/icon-size -n -t int -s $PANEL_ICON_SIZE\n" >&2
            xfconf-query -c "xfce4-panel" -p "${PLUGIN_ID}/icon-size" -n -t int -s "$PANEL_ICON_SIZE"
            ;;

        esac

    done < <(echo "$PANEL_PLUGINS")

fi

WHISKER_SETTINGS=(
    "menu-width=$(bc <<<"400 * $_MULTIPLIER / 1")"
    "menu-height=$(bc <<<"500 * $_MULTIPLIER / 1")"
    "item-icon-size=$(bc <<<"v = 2 * $_MULTIPLIER / 1; if (v < 0) v = 0; if (v > 10) v = 10; v")"
    "category-icon-size=$(bc <<<"v = 2 * $_MULTIPLIER / 1 - 1; if (v < 0) v = 0; if (v > 10) v = 10; v")"
)

for FILE in "$HOME/.config/xfce4/panel/"whiskermenu*.rc; do

    NEW_SETTINGS="$(
        array_join_by $'\n' "${WHISKER_SETTINGS[@]}"
        grep -Ev '^(menu-(width|height)|(item|category)-icon-size)=' "$FILE"
    )"

    if ! diff <(sort "$FILE" | grep -Ev '^\s*$') <(echo "$NEW_SETTINGS" | sort | grep -Ev '^\s*$') >/dev/null; then

        cp -pf "$FILE" "$FILE.bak"
        echo -e "Setting ${WHISKER_SETTINGS[*]} in $FILE\n" >&2
        echo "$NEW_SETTINGS" >"$FILE"
        echo >>"$FILE"
        RESTART_PANEL=1

    fi

done

if command_exists dconf; then

    if PLANK_DOCKS="$(dconf list "/net/launchpad/plank/docks/" 2>/dev/null)" &&
        [ -n "$PLANK_DOCKS" ]; then

        while IFS= read -r PLANK_DOCK; do

            # Plank icon size
            echo -e "dconf write /net/launchpad/plank/docks/${PLANK_DOCK}icon-size ${_48}\n" >&2
            dconf write "/net/launchpad/plank/docks/${PLANK_DOCK}icon-size" "${_48}"

        done < <(echo "$PLANK_DOCKS")

    fi

else

    echo -e "WARNING: dconf command not available\n" >&2

fi

if [ "$RESTART_PANEL" -eq "1" ]; then

    echo -e "xfce4-panel -r\n" >&2
    nohup xfce4-panel -r >/dev/null 2>&1 &

fi
