#!/bin/bash
# shellcheck disable=SC1090,SC2034

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

if has_argument "--lightdm"; then

    LK_DIE_HAPPY=Y
    assert_root

else

    assert_not_root

fi

assert_command_exists xrandr
assert_command_exists bc

if has_argument "-h" || has_argument "--help"; then

    die "Usage: $(basename "$0") [--autostart] [--set-all] [--suggest] [--get-shell-env] [--set-dpi] [--update-lightdm]"

fi

# ! is_autostart || sleep 2

# if the primary output's actual DPI is above this, enable "Retina" mode
HIDPI_THRESHOLD=144

# get current state with trailing whitespace removed
XRANDR_OUTPUT="$(xrandr --verbose | gnu_sed -E 's/[[:space:]]+$//')" || die "Unable to retrieve current RandR state"

# convert to single line for upcoming greps
XRANDR_OUTPUT="\\n${XRANDR_OUTPUT//$'\n'/\\n}"

# extract connected output names
OUTPUTS=($(echo "$XRANDR_OUTPUT" | gnu_grep -Po '(?<=\\n)([^[:space:]]+)(?= connected)')) || die "No connected outputs"

# and all output names (i.e. connected and disconnected)
ALL_OUTPUTS=($(echo "$XRANDR_OUTPUT" | gnu_grep -Po '(?<=\\n)([^[:space:]]+)(?= (connected|disconnected))'))

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
DPI_MULTIPLIER=1

# general xrandr options should be added to this array
# output-specific options belong in OPTIONS_xxx, where xxx is the output name's index in OUTPUTS
OPTIONS=()

LARGEST_AREA=0

for i in "${!OUTPUTS[@]}"; do

    # extract everything related to this output
    OUTPUT_INFO="$(echo "$XRANDR_OUTPUT" | gnu_grep -Po '(?<=\\n)'"${OUTPUTS[$i]}"' connected.*?(?=(\\n[^[:space:]])|$)')"

    OUTPUT_INFO_LINES="${OUTPUT_INFO//\\n/$'\n'}"

    # save it for later
    OUTPUTS_INFO+=("$OUTPUT_INFO_LINES")

    # extract EDID
    EDID="$(echo "$OUTPUT_INFO" | gnu_grep -Po '(?<=EDID:\\n)(\t{2}[0-9a-fA-F]+\\n)+')"
    EDID="${EDID//[^0-9a-fA-F]/}"
    EDIDS+=("$EDID")

    # extract dimensions
    DIMENSIONS=($(echo "$OUTPUT_INFO_LINES" | head -n1 | gnu_grep -Po '\b[0-9]+(?=mm\b)')) || DIMENSIONS=()

    if [ "${#DIMENSIONS[@]}" -eq 2 ] && ((AREA = DIMENSIONS[0] * DIMENSIONS[1])); then

        DIMENSIONS+=("$AREA")
        DIMENSIONS+=("$(echo "scale=10;size=sqrt(${DIMENSIONS[0]}^2+${DIMENSIONS[1]}^2)/10/2.54;scale=1;size/1" | bc)")
        SIZES+=("${DIMENSIONS[*]}")

        if [ "$AREA" -gt "$LARGEST_AREA" ]; then

            LARGEST_AREA="$AREA"
            PRIMARY_INDEX="$i"

        fi

    else

        SIZES+=("0 0 0 0")

    fi

    # extract preferred (native) resolution
    PIXELS=($(echo "$OUTPUT_INFO_LINES" | grep -E '[[:space:]]\+preferred$' | gnu_grep -Po '(?<=[[:space:]]|x)[0-9]+(?=[[:space:]]|x)')) ||
        PIXELS=($(echo "$OUTPUT_INFO_LINES" | grep -E '^[[:space:]]+[0-9]+x[0-9]+[[:space:]]' | sort -Vr | head -n1 | gnu_grep -Po '(?<=[[:space:]]|x)[0-9]+(?=[[:space:]]|x)')) ||
        PIXELS=()

    if [ "${#PIXELS[@]}" -eq 2 ]; then

        RESOLUTIONS+=("${PIXELS[*]}")

        if [ "$PRIMARY_INDEX" -eq "$i" ] && [ "${#DIMENSIONS[@]}" -eq "4" ] && [ "${DIMENSIONS[0]}" -gt "0" ]; then

            ACTUAL_DPI="$(echo "scale=10;dpi=${PIXELS[0]}/(${DIMENSIONS[0]}/10/2.54);scale=0;dpi/1" | bc)"
            PRIMARY_SIZE="${DIMENSIONS[3]}"

        fi

    else

        RESOLUTIONS+=("0 0")

    fi

    # create an output-specific options array
    eval "OPTIONS_$i=()"

done

echo "Actual DPI of largest screen${PRIMARY_SIZE:+ ($PRIMARY_SIZE\")}: $ACTUAL_DPI" >&2

if [ "$ACTUAL_DPI" -ge "$HIDPI_THRESHOLD" ]; then

    SCALING_FACTOR=2
    DPI=192

fi

# Usage: get_edid_index "00ffffffffffff00410c03c1...5311000a20202020202000af"
# Outputs nothing and exits non-zero if the value isn't found.
function get_edid_index() {

    array_search "$1" EDIDS

}

if [ ! -e "$CONFIG_DIR/xrandr" ] || has_argument "--suggest"; then

    {

        echo '#!/bin/bash'
        echo
        echo '# This file has been automatically generated. Rename it to "xrandr" before making changes.'
        echo

        for i in "${!OUTPUTS[@]}"; do

            DIMENSIONS=(${SIZES[$i]})
            RESOLUTION=(${RESOLUTIONS[$i]})

            echo "# ${DIMENSIONS[3]}\", ${RESOLUTION[0]}x${RESOLUTION[1]}"
            echo "EDID_DISPLAY_${i}=\"${EDIDS[$i]}\""
            echo "EDID_DISPLAY_${i}_OPTIONS=()"
            echo

        done

        cat <<EOF
for i in \$(seq 0 $i); do
    eval "EDID_DISPLAY_\${i}_ACTIVE=0"
    if eval "EDID_DISPLAY_\${i}_INDEX=\\"\\\$(get_edid_index \\"\\\$EDID_DISPLAY_\${i}\\")\\""; then
        eval "EDID_DISPLAY_\${i}_ACTIVE=1"
    fi
done

# Modify any of the following variables here:
# - EDID_DISPLAY_i_OPTIONS (array)
# - OPTIONS (array)
# - DPI
# - DPI_MULTIPLIER
# - SCALING_FACTOR (integer)
# - PRIMARY_INDEX
#
# See $CONFIG_DIR/xrandr-example and $SCRIPT_PATH for more information

for i in \$(seq 0 $i); do
    eval "EDID_DISPLAY_ACTIVE=\\"\\\$EDID_DISPLAY_\${i}_ACTIVE\\""
    if [ "\$EDID_DISPLAY_ACTIVE" -eq "1" ]; then
        eval "EDID_DISPLAY_INDEX=\\"\\\$EDID_DISPLAY_\${i}_INDEX\\""
        eval "OPTIONS_\${EDID_DISPLAY_INDEX}+=(\\"\\\${EDID_DISPLAY_\${i}_OPTIONS[@]}\\")"
    fi
done
EOF

    } >"$CONFIG_DIR/xrandr-suggested"

    ! has_argument "--suggest" || exit 0

fi

# OPTIONS, OPTIONS_xxx, PRIMARY_INDEX, SCALING_FACTOR, DPI and DPI_MULTIPLIER may be changed here
if [ -e "$CONFIG_DIR/xrandr" ]; then

    . "$CONFIG_DIR/xrandr" || die

fi

DPI="$(echo "scale=10;dpi=$DPI*$DPI_MULTIPLIER;scale=0;dpi/1" | bc)"

{
    echo "Scaling factor: $SCALING_FACTOR"
    echo "Effective DPI: $DPI"
} >&2

if has_argument "--get-shell-env"; then

    ((QT_FONT_DPI = DPI / SCALING_FACTOR))

    echo "export QT_AUTO_SCREEN_SCALE_FACTOR=\"0\""
    echo "export QT_SCALE_FACTOR=\"$SCALING_FACTOR\""
    echo "export QT_FONT_DPI=\"$QT_FONT_DPI\""

fi

if has_argument "--set-dpi"; then

    {
        xrandr --dpi "$DPI"
        echo "Xft.dpi: $DPI" | xrdb -merge
    } >&2

fi

in_array "--dpi" OPTIONS || OPTIONS+=(--dpi "$DPI")

for i in "${!OUTPUTS[@]}"; do

    OPTIONS+=(--output "${OUTPUTS[$i]}")

    eval "OPTIONS_COUNT=(\"\${#OPTIONS_${i}[@]}\")"

    if [ "$OPTIONS_COUNT" -gt "0" ]; then

        eval "OUTPUT_OPTIONS=(\"\${OPTIONS_${i}[@]}\")"
        OPTIONS+=("${OUTPUT_OPTIONS[@]}")

    else

        OUTPUT_OPTIONS=()

    fi

    if ! in_array "--off" OUTPUT_OPTIONS; then

        in_array "--mode" OUTPUT_OPTIONS || OPTIONS+=(--preferred)
        in_array "--pos" OUTPUT_OPTIONS || OPTIONS+=(--pos 0x0)
        in_array "--brightness" OUTPUT_OPTIONS || OPTIONS+=(--brightness 1.0)
        in_array "--primary" OPTIONS || [ "$PRIMARY_INDEX" -ne "$i" ] || OPTIONS+=(--primary)
        in_array "Broadcast RGB" OUTPUT_OPTIONS || OPTIONS+=(--set "Broadcast RGB" "Full")

    fi

done

RESET_OPTIONS=()

for i in "${ALL_OUTPUTS[@]}"; do

    RESET_OPTIONS+=(--output "$i")

    if ! in_array "$i" OUTPUTS; then

        RESET_OPTIONS+=(--off)

    else

        RESET_OPTIONS+=(--auto --transform none --panning 0x0)

    fi

done

if has_argument "--set-all" || has_argument "--lightdm" || is_autostart; then

    # check that our configuration is valid
    xrandr --dryrun "${RESET_OPTIONS[@]}" >/dev/null || die
    xrandr --dryrun "${OPTIONS[@]}" >/dev/null || die

    # apply configuration
    echo "xrandr ${RESET_OPTIONS[*]}" >&2
    xrandr "${RESET_OPTIONS[@]}" || true
    echo "xrandr ${OPTIONS[*]}" >&2
    xrandr "${OPTIONS[@]}" || die

    has_argument "--lightdm" || ! lk_command_exists "displaycal-apply-profiles" ||
        displaycal-apply-profiles

fi

! has_argument "--lightdm" || exit 0

function get_lightdm_conf() {

    cat <<EOF
[Seat:*]
display-setup-script='$SCRIPT_PATH' --lightdm
EOF

}

LIGHTDM_CONF_FILE="/etc/lightdm/lightdm.conf.d/90-xrandr-auto.conf"

if has_argument "--update-lightdm" &&
    [ -d "/etc/lightdm/lightdm.conf.d" ] &&
    { [ ! -e "$LIGHTDM_CONF_FILE" ] || diff "$LIGHTDM_CONF_FILE" <(get_lightdm_conf) >/dev/null; }; then

    get_lightdm_conf | sudo -n tee "$LIGHTDM_CONF_FILE" >/dev/null 2>&1 || echo $'WARNING: unable to configure LightDM\n' >&2

fi

# ok, xrandr is sorted -- look after everything else

case "${XDG_CURRENT_DESKTOP:-}" in

XFCE)

    # prevent Xfce from interfering with our display settings
    xfconf-query -c displays -p / -rR
    xfconf-query -c displays -p /Notify -n -t bool -s false

    if ! is_desktop; then

        # by default, suspend when laptop lid is closed
        XFCE4_LID_ACTION=1

        # unless more than one output is connected (0 = switch off display)
        [ "${#OUTPUTS[@]}" -le "1" ] || XFCE4_LID_ACTION=0

        xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lid-action-on-ac -n -t uint -s "$XFCE4_LID_ACTION"

    fi

    "$SCRIPT_DIR/xfce4-set-dpi.sh" "${XFCE4_DPI:-$DPI}"
    ;;

*)

    echo "Xft.dpi: $DPI" | xrdb -merge
    ;;

esac

if gsettings get org.gnome.desktop.interface scaling-factor >/dev/null 2>&1; then

    gsettings set org.gnome.desktop.interface scaling-factor "$SCALING_FACTOR" || true
    gsettings set org.gnome.desktop.interface text-scaling-factor "$DPI_MULTIPLIER" || true

fi

if ! is_autostart; then

    "$SCRIPT_DIR/x-release-modifiers.sh"

fi

"$SCRIPT_DIR/xkb-load.sh" "$@"
# "$SCRIPT_DIR/xinput-load.sh" "$@"

lk_start_or_restart quicktile --daemonize
lk_start_or_restart devilspie2
lk_start_or_restart plank

# Plank needs a little time
sleep 2
