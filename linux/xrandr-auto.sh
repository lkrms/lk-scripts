#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_command_exists xrandr
assert_command_exists bc

# if the primary output's actual DPI is above this, enable "Retina" mode
HIDPI_THRESHOLD=120

# remove trailing whitespace
XRANDR_OUTPUT="$(
    set -euo pipefail
    xrandr --verbose | sed -E 's/[[:space:]]+$//'
)"

# convert to single line for upcoming greps
XRANDR_OUTPUT="\\n${XRANDR_OUTPUT//$'\n'/\\n}\\n"

# extract connected output names
OUTPUTS=($(
    set -euo pipefail
    echo "$XRANDR_OUTPUT" | grep -Po '(?<=\\n)([^[:space:]]+)(?= connected)'
))

# and all output names (i.e. connected and disconnected)
ALL_OUTPUTS=($(
    set -euo pipefail
    echo "$XRANDR_OUTPUT" | grep -Po '(?<=\\n)([^[:space:]]+)(?= (connected|disconnected))'
))

[ "${#OUTPUTS[@]}" -gt 0 ] || die "Error: no connected outputs"

# each EDID is stored at the same index as its output name in OUTPUTS
EDIDS=()

# physical dimensions are stored here at the same index (e.g. "435 239 103965", or "<width> <height> <area>")
SIZES=()

# native resolutions are stored here at the same index (e.g. "1920 1080")
RESOLUTIONS=()

# verbose xrandr output is stored here at the same index
OUTPUTS_INFO=()

# by default, the largest output (by physical area) will be set as primary
PRIMARY_INDEX=0

# the largest output is also used to determine DPI and scaling factor
ACTUAL_DPI=96
SCALING_FACTOR=1
DPI=96

# general xrandr options should be added here
# output-specific options belong in OPTIONS_xxx, where xxx is the output name's index in OUTPUTS
OPTIONS=()

LARGEST_AREA=0

for i in "${!OUTPUTS[@]}"; do

    # extract everything related to this output
    OUTPUT_INFO="$(
        set -euo pipefail
        echo "$XRANDR_OUTPUT" | grep -Po '(?<=\\n)'"${OUTPUTS[$i]}"' connected.*?(?=\\n[^[:space:]])'
    )"

    OUTPUT_INFO_LINES="${OUTPUT_INFO//\\n/$'\n'}"

    # save it for later
    OUTPUTS_INFO+=("$OUTPUT_INFO_LINES")

    # extract EDID
    EDID="$(
        set -euo pipefail
        echo "$OUTPUT_INFO" | grep -Po '(?<=EDID:\\n)(\t{2}[0-9a-fA-F]+\\n)+'
    )"
    EDID="${EDID//[^0-9a-fA-F]/}"
    EDIDS+=("$EDID")

    # extract dimensions
    DIMENSIONS=($(
        set -euo pipefail
        echo "$OUTPUT_INFO_LINES" | head -n1 | grep -Po '\b[0-9]+(?=mm\b)'
    ))
    if [ "${#DIMENSIONS[@]}" -eq 2 ]; then

        let AREA=DIMENSIONS[0]*DIMENSIONS[1]
        DIMENSIONS+=("$AREA")
        SIZES+=("${DIMENSIONS[*]}")

        if [ "$AREA" -gt "$LARGEST_AREA" ]; then

            LARGEST_AREA="$AREA"
            PRIMARY_INDEX="$i"

        fi

    else

        SIZES+=("0 0 0")

    fi

    # extract preferred (native) resolution
    PIXELS=($(
        set -euo pipefail
        echo "$OUTPUT_INFO_LINES" | grep '[[:space:]]+preferred$' | grep -Po '(?<=[[:space:]]|x)[0-9]+(?=[[:space:]]|x)'
    ))
    if [ "${#PIXELS[@]}" -eq 2 ]; then

        RESOLUTIONS+=("${PIXELS[*]}")

        if [ "$PRIMARY_INDEX" -eq "$i" ] && [ "${#DIMENSIONS[@]}" -eq "3" ] && [ "${DIMENSIONS[0]}" -gt "0" ]; then

            ACTUAL_DPI="$(
                set -euo pipefail
                echo "scale = 10; dpi = ${PIXELS[0]} / ( ${DIMENSIONS[0]} / 10 / 2.54 ); scale = 0; dpi / 1" | bc
            )"

        fi

    else

        RESOLUTIONS+=("0 0")

    fi

    # create an output-specific options array
    eval "OPTIONS_$i=()"

done

if [ "$ACTUAL_DPI" -gt "$HIDPI_THRESHOLD" ]; then

    SCALING_FACTOR=2
    DPI=192

fi

# Usage: get_edid_index "00ffffffffffff00410c03c1...5311000a20202020202000af"
# Outputs nothing and exits non-zero if the value isn't found.
function get_edid_index() {

    array_search "$1" EDIDS

}

# customise OPTIONS, OPTIONS_xxx, PRIMARY_INDEX, SCALING_FACTOR and DPI here
if [ -e "$CONFIG_DIR/xrandr" ]; then

    # shellcheck source=../config/xrandr
    . "$CONFIG_DIR/xrandr" || die

fi

array_search "--dpi" OPTIONS >/dev/null || OPTIONS+=(--dpi "$DPI")

for i in "${!OUTPUTS[@]}"; do

    OPTIONS+=(--output "${OUTPUTS[$i]}")

    eval "OUTPUT_OPTIONS=(\"\${OPTIONS_${i}[@]}\")"

    array_search "--mode" OUTPUT_OPTIONS >/dev/null || OUTPUT_OPTIONS+=(--preferred)

    array_search "--primary" OPTIONS >/dev/null || [ "$PRIMARY_INDEX" -ne "$i" ] || OUTPUT_OPTIONS+=(--primary)

    array_search "Broadcast RGB" OUTPUT_OPTIONS >/dev/null || OUTPUT_OPTIONS+=(--set "Broadcast RGB" "Full")

    OPTIONS+=("${OUTPUT_OPTIONS[@]}")

done

RESET_OPTIONS=()

for i in "${ALL_OUTPUTS[@]}"; do

    RESET_OPTIONS+=(--output "$i")

    if ! array_search "$i" OUTPUTS >/dev/null; then

        RESET_OPTIONS+=(--off)

    else

        RESET_OPTIONS+=(--auto --transform none --panning 0x0)

    fi

done

# check that our configuration is valid
xrandr --dryrun "${RESET_OPTIONS[@]}" >/dev/null
xrandr --dryrun "${OPTIONS[@]}" >/dev/null

# apply configuration
xrandr "${RESET_OPTIONS[@]}" || true
xrandr "${OPTIONS[@]}"

# ok, xrandr is sorted -- look after everything else
let XFT_DPI=1024*DPI

if command_exists gsettings; then

    # TODO: update existing/default overrides rather than assuming elementary OS defaults
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

RC_CONTENT=$(grep -Ev '^xrandr --dpi [0-9]+$' "$XSESSIONRC")
echo "$RC_CONTENT" >"$XSESSIONRC"
echo "xrandr --dpi $DPI" >>"$XSESSIONRC"

if command_exists displaycal-apply-profiles; then

    displaycal-apply-profiles || true

fi
