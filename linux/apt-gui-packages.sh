#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-apt
. "$SCRIPT_DIR/../bash/common-apt"

[ "$#" -gt "0" ] || die "Usage: $(basename "$0") package1..."

apt_refresh_packages

PACKAGES=($(printf '%s\n' "$@" | sort | uniq))

GUI_PACKAGES=($(comm -12 <(printf '%s\n' "${APT_GUI_PACKAGES[@]}") <(printf '%s\n' "${PACKAGES[@]}")))
console_message "${#GUI_PACKAGES[@]} $(single_or_plural "${#GUI_PACKAGES[@]}" package packages) likely to have a GUI:" "${GUI_PACKAGES[*]}" "$BOLD" "$GREEN"

UNKNOWN_PACKAGES=($(comm -13 <(printf '%s\n' "${APT_AVAILABLE_PACKAGES[@]}") <(printf '%s\n' "${PACKAGES[@]}")))
console_message "${#UNKNOWN_PACKAGES[@]} unknown $(single_or_plural "${#UNKNOWN_PACKAGES[@]}" package packages):" "${UNKNOWN_PACKAGES[*]}" "$BOLD" "$RED"
