#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_command_exists xfconf-query

CHANNELS=($(xfconf-query -l | tail -n +2 | sort -f))

{

    for CHANNEL in "${CHANNELS[@]}"; do

        while read -r PROPERTY VALUE; do

            printf '%s,%s,"%s"\n' "$CHANNEL" "$PROPERTY" "$VALUE"

        done < <(xfconf-query -c "$CHANNEL" -lv | sort -f)

    done

} | tee "xfconf-dump-$(date_get_ymdhms)"
