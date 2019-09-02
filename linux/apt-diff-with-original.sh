#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-apt
. "$SCRIPT_DIR/../bash/common-apt"

assert_not_root

[ "$#" -eq "1" ] || die "Usage: $(basename "$0") </path/to/changed/file>"

FILE_PATH="$(readlink -e "$1")"

PACKAGES=($(
    . "$SUBSHELL_SCRIPT_PATH" || exit
    dpkg-query -S "$FILE_PATH" | sed 's/:.*$//' | sort | uniq
))

[ "${#PACKAGES[@]}" -gt "0" ] || die "Package couldn't be identified for $1"

apt_mark_cache_clean

for p in "${PACKAGES[@]}"; do

    apt_package_installed "$p" || continue

    DOWNLOAD_INFO=($(apt-get "${APT_GET_OPTIONS[@]}" download --print-uris "$p")) && [ "${#DOWNLOAD_INFO[@]}" -ge "2" ] || continue

    eval url="${DOWNLOAD_INFO[0]}"
    EXTRACT_PATH="$TEMP_DIR/extract/${DOWNLOAD_INFO[1]}"

    if [ ! -d "$EXTRACT_PATH" ]; then

        mkdir -p "$APT_DEB_PATH" "$(dirname "$EXTRACT_PATH")"
        rm -Rf "$EXTRACT_PATH"

        pushd "$APT_DEB_PATH" >/dev/null
        console_message "Downloading:" "$url" "$CYAN"
        DEB_PATH="$(download_urls "$url")"
        popd >/dev/null

        dpkg-deb -x "$DEB_PATH" "$EXTRACT_PATH" || {
            rm -Rf "$EXTRACT_PATH"
            false
        }

    fi

    if [ -e "$EXTRACT_PATH$1" ]; then

        diff "$EXTRACT_PATH$1" "$1" || true
        exit

    fi

done

die "Unable to find original version of $1. Searched in: ${PACKAGES[*]}"
