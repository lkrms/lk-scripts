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

[ "$#" -ge "1" ] && [ -f "$1" ] || die "Usage: $(basename "$0") </path/to/file> [diff option...]"

FILE_PATH="$(realpath "$1")"

shift

PACKAGES=($(
    . "$SUBSHELL_SCRIPT_PATH" || exit
    dpkg-query -S "$FILE_PATH" 2>/dev/null | sed 's/:.*$//' | sort | uniq
)) && [ "${#PACKAGES[@]}" -gt "0" ] || die "Error: $FILE_PATH doesn't belong to a package"

apt_mark_cache_clean

for p in "${PACKAGES[@]}"; do

    apt_package_installed "$p" || continue

    DOWNLOAD_INFO=($(apt-get "${APT_GET_OPTIONS[@]}" download --print-uris "$p" 2>/dev/null)) && [ "${#DOWNLOAD_INFO[@]}" -ge "2" ] || {
        console_message "Unable to get archive URI for package:" "$p" "$BOLD" "$RED" >&2
        continue
    }

    console_message "File appears to belong to package:" "$p" "$CYAN" >&2

    # easiest way to eliminate the enclosing quotes
    eval "URL=${DOWNLOAD_INFO[0]}"
    EXTRACT_PATH="${TEMP_DIR}/extract/${DOWNLOAD_INFO[1]}"

    if [ ! -d "$EXTRACT_PATH" ]; then

        mkdir -p "$APT_DEB_PATH" "$(dirname "$EXTRACT_PATH")"
        rm -Rf "$EXTRACT_PATH"

        pushd "$APT_DEB_PATH" >/dev/null || die
        console_message "Downloading package archive:" "${NO_WRAP}${URL}${WRAP}" "$CYAN" >&2
        DEB_PATH="$(download_urls "$URL")" || die
        popd >/dev/null

        console_message "Extracting package archive to temporary folder" "" "$CYAN" >&2
        dpkg-deb -x "$DEB_PATH" "$EXTRACT_PATH" || {
            rm -Rf "$EXTRACT_PATH"
            die
        }

    else

        console_message "Package archive already available in temporary folder" "" "$CYAN" >&2

    fi

    if [ -e "${EXTRACT_PATH}${FILE_PATH}" ]; then

        console_message "Comparing with original version:" "$FILE_PATH" "$BOLD" "$MAGENTA" >&2

        if diff "$@" "${EXTRACT_PATH}${FILE_PATH}" "$FILE_PATH"; then

            console_message "No differences found" "" "$BOLD" "$GREEN" >&2

        fi

        exit

    else

        console_message "Original version of file not found in package:" "$p" "$BOLD" "$RED" >&2

    fi

done

console_message "Unable to find original version of file. ${#PACKAGES[@]} $(single_or_plural "${#PACKAGES[@]}" package packages) checked:" "${PACKAGES[*]}" >&2
