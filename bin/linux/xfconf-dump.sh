#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_command_exists xfconf-query

CHANNELS=($(xfconf-query -l | tail -n +2 | sort -f))

{

    for CHANNEL in "${CHANNELS[@]}"; do

        while read -r PROPERTY VALUE; do

            printf '%s,%s,"%s"\n' "$CHANNEL" "$PROPERTY" "$VALUE"

        done < <(xfconf-query -c "$CHANNEL" -lv | sort -f)

    done

} | tee "xfconf-dump-$(date_get_ymdhms)"
