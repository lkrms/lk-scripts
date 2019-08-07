#!/bin/bash
# shellcheck disable=SC2206,SC2207

# Recommended:
# - create ../config/xrandr
# - add "/path/to/linux/xrandr-auto.sh --autostart" to your desktop environment's startup applications
# - bind a keyboard shortcut (e.g. Ctrl+Alt+R) to "/path/to/linux/xrandr-auto.sh"
# - create "/etc/lightdm/lightdm.conf.d/xrandr.conf" as:
#     [SeatDefaults]
#     display-setup-script=/path/to/linux/xrandr-auto.sh

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_command_exists xrandr
assert_command_exists bc

IS_AUTOSTART=0
[ "${1:-}" = "--autostart" ] && IS_AUTOSTART=1 || true

# if the primary output's actual DPI is above this, enable "Retina" mode
HIDPI_THRESHOLD=144

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
)) || die "Error: no connected outputs"

# and all output names (i.e. connected and disconnected)
ALL_OUTPUTS=($(
    set -euo pipefail
    echo "$XRANDR_OUTPUT" | grep -Po '(?<=\\n)([^[:space:]]+)(?= (connected|disconnected))'
))

# each EDID is stored at the same index as its output name in OUTPUTS
EDIDS=()

# physical dimensions are stored here at the same index (e.g. "435 239 103965 19.5", or "<width> <height> <area> <diagonal inches>")
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

# general xrandr options should be added to this array
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
    )) || DIMENSIONS=()
    if [ "${#DIMENSIONS[@]}" -eq 2 ]; then

        ((AREA = DIMENSIONS[0] * DIMENSIONS[1]))
        DIMENSIONS+=("$AREA")
        DIMENSIONS+=("$(
            set -euo pipefail
            echo "scale = 10; size = sqrt(${DIMENSIONS[0]} ^ 2 + ${DIMENSIONS[1]} ^ 2) / 10 / 2.54; scale = 1; size / 1" | bc
        )")
        SIZES+=("${DIMENSIONS[*]}")

        if [ "$AREA" -gt "$LARGEST_AREA" ]; then

            LARGEST_AREA="$AREA"
            PRIMARY_INDEX="$i"

        fi

    else

        SIZES+=("0 0 0 0")

    fi

    # extract preferred (native) resolution
    PIXELS=($(
        set -euo pipefail
        echo "$OUTPUT_INFO_LINES" | grep '[[:space:]]+preferred$' | grep -Po '(?<=[[:space:]]|x)[0-9]+(?=[[:space:]]|x)'
    )) || PIXELS=()
    if [ "${#PIXELS[@]}" -eq 2 ]; then

        RESOLUTIONS+=("${PIXELS[*]}")

        if [ "$PRIMARY_INDEX" -eq "$i" ] && [ "${#DIMENSIONS[@]}" -eq "4" ] && [ "${DIMENSIONS[0]}" -gt "0" ]; then

            ACTUAL_DPI="$(
                set -euo pipefail
                echo "scale = 10; dpi = ${PIXELS[0]} / ( ${DIMENSIONS[0]} / 10 / 2.54 ); scale = 0; dpi / 1" | bc
            )"
            PRIMARY_SIZE="${DIMENSIONS[3]}"

        fi

    else

        RESOLUTIONS+=("0 0")

    fi

    # create an output-specific options array
    eval "OPTIONS_$i=()"

done

echo "Actual DPI of largest screen (${PRIMARY_SIZE:-??}\"): $ACTUAL_DPI" >&2

if [ "$ACTUAL_DPI" -ge "$HIDPI_THRESHOLD" ]; then

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

if [ ! -e "$CONFIG_DIR/xrandr" ] || [ "${1:-}" = "--suggest" ]; then

    CONFIG_FILE="$CONFIG_DIR/xrandr-suggested"

    echo -e '#!/bin/bash\n' >"$CONFIG_FILE"
    echo -e '# This file has been automatically generated. Rename it to xrandr before making changes.\n' >>"$CONFIG_FILE"

    for i in "${!OUTPUTS[@]}"; do

        DIMENSIONS=(${SIZES[$i]})
        RESOLUTION=(${RESOLUTIONS[$i]})

        {
            echo "# ${DIMENSIONS[3]}\", ${RESOLUTION[0]}x${RESOLUTION[1]}"
            echo "EDID_DISPLAY_${i}=\"${EDIDS[$i]}\""
            echo "EDID_DISPLAY_${i}_OPTIONS=()"
            echo
        } >>"$CONFIG_FILE"

    done

    cat <<EOF >>"$CONFIG_FILE"
for i in \$(seq 0 ${#OUTPUTS[@]}); do
    eval "EDID_DISPLAY_\${i}_ACTIVE=0"
    if eval "EDID_DISPLAY_\${i}_INDEX=\\"\\\$(get_edid_index \\"\\\$EDID_DISPLAY_\${i}\\")\\""; then
        eval "EDID_DISPLAY_\${i}_ACTIVE=1"
    fi
done

# Here's an example to use as a starting point.
# In addition to output-specific options, you can also modify: OPTIONS, PRIMARY_INDEX, SCALING_FACTOR, DPI
#
# # 4K connected?
# if [ "\$EDID_DISPLAY_0_ACTIVE" -eq "1" ]; then
#
#     # "looks like 2560x1440"
#     EDID_DISPLAY_0_OPTIONS+=(--mode 3840x2160 --scale-from 5120x2880)
#
#     # 1080p also connected?
#     if [ "\$EDID_DISPLAY_1_ACTIVE" -eq "1" ]; then
#
#         # "looks like 1536x864" - i.e. use all of i915's (software-limited) 8192x8192 framebuffer
#         EDID_DISPLAY_1_OPTIONS+=(--mode 1920x1080 --scale-from 3072x1728 --pos 0x576)
#         EDID_DISPLAY_0_OPTIONS+=(--pos 3072x0)
#
#     fi
#
# fi

for i in \$(seq 0 ${#OUTPUTS[@]}); do
    eval "EDID_DISPLAY_ACTIVE=\\"\\\$EDID_DISPLAY_\${i}_ACTIVE\\""
    if [ "\$EDID_DISPLAY_ACTIVE" -eq "1" ]; then
        eval "EDID_DISPLAY_INDEX=\\"\\\$EDID_DISPLAY_\${i}_INDEX\\""
        eval "OPTIONS_\${EDID_DISPLAY_INDEX}+=(\\"\\\${EDID_DISPLAY_\${i}_OPTIONS[@]}\\")"
    fi
done
EOF

fi

echo "Scaling factor: $SCALING_FACTOR" >&2
echo "Effective DPI: $DPI" >&2

if [ "${1:-}" = "--dpi-only" ]; then

    echo -e "\nxrandr --dpi $DPI\n" >&2
    xrandr --dpi "$DPI"
    exit

fi

if [ "${1:-}" = "--get-scaling-factor" ]; then

    echo "$SCALING_FACTOR"
    exit

fi

array_search "--dpi" OPTIONS >/dev/null || OPTIONS+=(--dpi "$DPI")

for i in "${!OUTPUTS[@]}"; do

    OPTIONS+=(--output "${OUTPUTS[$i]}")

    set +u
    eval "OUTPUT_OPTIONS=(\"\${OPTIONS_${i}[@]}\")"
    set -u

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
echo -e "\nxrandr ${RESET_OPTIONS[*]}\n" >&2
xrandr "${RESET_OPTIONS[@]}" || true
echo -e "xrandr ${OPTIONS[*]}\n" >&2
xrandr "${OPTIONS[@]}"

# ok, xrandr is sorted -- look after everything else
if command_exists gsettings; then

    (
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit

        set +u

        SUDO_OR_NOT=()
        DBUS_KILL_PID=

        if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then

            if [ "$EUID" -eq "0" ] && user_exists "lightdm"; then

                SUDO_OR_NOT=(sudo -u lightdm -HE)

                DBUS_LAUNCH_CODE="$("${SUDO_OR_NOT[@]}" dbus-launch --sh-syntax)" || exit 0

                # shellcheck disable=SC1090
                . <(echo "$DBUS_LAUNCH_CODE")

                DBUS_KILL_PID="$DBUS_SESSION_BUS_PID"

                echo "D-Bus process started: $DBUS_SESSION_BUS_PID" >&2

            else

                exit

            fi

        fi

        ((XFT_DPI = 1024 * DPI))

        OVERRIDES="$("${SUDO_OR_NOT[@]}" gsettings get org.gnome.settings-daemon.plugins.xsettings overrides)"
        OVERRIDES="$("$SCRIPT_DIR/glib-update-variant-dictionary.py" "$OVERRIDES" 'Gdk/WindowScalingFactor' "$SCALING_FACTOR")"
        OVERRIDES="$("$SCRIPT_DIR/glib-update-variant-dictionary.py" "$OVERRIDES" 'Xft/DPI' "$XFT_DPI")"

        echo -e "${SUDO_OR_NOT[*]} gsettings set org.gnome.settings-daemon.plugins.xsettings overrides \"$OVERRIDES\"\n" >&2
        "${SUDO_OR_NOT[@]}" gsettings set org.gnome.settings-daemon.plugins.xsettings overrides "$OVERRIDES" || true
        echo -e "${SUDO_OR_NOT[*]} gsettings set org.gnome.desktop.interface scaling-factor $SCALING_FACTOR\n" >&2
        "${SUDO_OR_NOT[@]}" gsettings set org.gnome.desktop.interface scaling-factor "$SCALING_FACTOR" || true

        if [ -n "$DBUS_KILL_PID" ]; then

            if "${SUDO_OR_NOT[@]}" kill "$DBUS_KILL_PID"; then

                echo "D-Bus process killed: $DBUS_KILL_PID" >&2

            else

                echo "Unable to kill D-Bus process: $DBUS_KILL_PID" >&2

            fi

        fi

    )

fi

if command_exists displaycal-apply-profiles; then

    if [ "$IS_AUTOSTART" -eq "0" ] && [ "$EUID" -ne "0" ]; then

        displaycal-apply-profiles || true

    else

        echo "Skipped: displaycal-apply-profiles" >&2

    fi

fi

"$SCRIPT_DIR/xkb-load.sh" "$@"

if [ "$EUID" -ne "0" ]; then

    mkdir -p "$HOME/.local/bin"
    move_file_delete_link "$HOME/.local/bin/xrandr-auto.sh"
    ln -s "$ROOT_DIR/linux/xrandr-auto.sh" "$HOME/.local/bin/xrandr-auto.sh"

fi
