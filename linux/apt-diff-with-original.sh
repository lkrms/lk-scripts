#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/apt-common"

assert_not_root

if [ "$#" -ne "1" ]; then

    echo "Usage: $(basename "$0") </path/to/changed/file>"
    exit 1

fi

FILE_PATH="$(readlink -e "$1")" || {
    echo "File not found: $1"
    exit 1
}

PACKAGES=($(
    set -euo pipefail
    dpkg-query -S "$FILE_PATH" | sed 's/:.*$//' | sort | uniq
)) || exit 1

[ "${#PACKAGES[@]}" -gt "0" ] || {
    echo "Package couldn't be identified for $1"
    exit 1
}

for p in "${PACKAGES[@]}"; do

    apt_package_installed "$p" || continue

    DOWNLOAD_INFO=($(apt-get download --print-uris "$p")) && [ "${#DOWNLOAD_INFO[@]}" -ge "2" ] || continue

    eval url=${DOWNLOAD_INFO[0]}
    DEB_PATH="$(apt_deb_path "$url")"
    EXTRACT_PATH="$RS_TEMP_DIR/extract/${DOWNLOAD_INFO[1]}"

    if [ ! -d "$EXTRACT_PATH" ]; then

        mkdir -p "$(dirname "$DEB_PATH")" "$(dirname "$EXTRACT_PATH")"
        rm -Rf "$EXTRACT_PATH"

        console_message "Downloading:" "$url" $BLUE
        wget -qcO "$DEB_PATH" "$url"

        dpkg-deb -x "$DEB_PATH" "$EXTRACT_PATH" || {
            rm -Rf "$EXTRACT_PATH"
            false
        }

    fi

    if [ -e "$EXTRACT_PATH$1" ]; then

        diff "$EXTRACT_PATH$1" "$1"
        exit

    fi

done

echo "Unable to find $1. Searched in: $PACKAGES[*]"
exit 1
