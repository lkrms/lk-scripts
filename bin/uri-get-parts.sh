#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

[ "$#" -ge "1" ] || die "Usage: $(basename "$0") <any://valid.uri?with=any#parts> [scheme|username|password|host|ipv6_address|port|path|query|fragment...]"

URI="$1"

shift

if [ "$#" -gt "0" ]; then

    PARTS=("$@")

else

    PARTS=(scheme username password host ipv6_address port path query fragment)

fi

if [ -t 1 ]; then

    PARTS_RETURNED=()

    while IFS= read -r PART; do

        PARTS_RETURNED+=("$PART")

    done < <(uri_get_parts "$URI" "${PARTS[@]}")

    for i in "${!PARTS[@]}"; do

        printf "%s: %s\n" "${BOLD}${PARTS[$i]}${RESET}" "${PARTS_RETURNED[$i]}"

    done

else

    uri_get_parts "$URI" "${PARTS[@]}"

fi
