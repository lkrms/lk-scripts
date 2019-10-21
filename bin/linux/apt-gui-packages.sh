#!/bin/bash
# shellcheck disable=SC1090,SC2086
#
# Determine which of the given apt packages are likely to require a
# desktop environment. If no package names are given, consider all
# installed packages.
#

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"
. "$SCRIPT_DIR/../../bash/common-apt"

apt_refresh_packages

APT_GUI_PACKAGES="$(
    . "$SUBSHELL_SCRIPT_PATH" || exit
    apt-cache rdepends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances libwayland-client0 libwayland-server0 libx11-6 x11-common | grep -v " " | sort | uniq
)" || die

if [ "$#" -gt "0" ]; then

    PACKAGES="$(printf '%s\n' "$@" | gnu_grep -Po '^.*?(?=(:.*)?$)' | sort | uniq)"

else

    PACKAGES="$(printf '%s\n' $APT_INSTALLED_PACKAGES | gnu_grep -Po '^.*?(?=(:.*)?$)' | sort | uniq)"

fi

GUI_PACKAGES=($(comm -12 <(echo "$APT_GUI_PACKAGES") <(echo "$PACKAGES")))
UNKNOWN_PACKAGES=($(comm -13 <(echo "$APT_AVAILABLE_PACKAGES") <(echo "$PACKAGES")))

if [ "${#GUI_PACKAGES[@]}" -gt "0" ]; then

    console_message "${#GUI_PACKAGES[@]} $(single_or_plural "${#GUI_PACKAGES[@]}" package packages) likely to have a GUI:" "" "$BOLD" "$GREEN"
    printf '%s\n' "${GUI_PACKAGES[@]}" | column

else

    PACKAGE_COUNT="$(echo "$PACKAGES" | wc -w)"
    console_message "No packages likely to have a GUI ($PACKAGE_COUNT considered)" "" "$BOLD" "$GREEN"

fi

if [ "${#UNKNOWN_PACKAGES[@]}" -gt "0" ]; then

    console_message "${#UNKNOWN_PACKAGES[@]} unknown $(single_or_plural "${#UNKNOWN_PACKAGES[@]}" package packages):" "" "$BOLD" "$RED"
    printf '%s\n' "${UNKNOWN_PACKAGES[@]}" | column

fi
