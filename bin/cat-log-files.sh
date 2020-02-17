#!/bin/bash
# shellcheck disable=SC1090,SC2015

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

[ "$#" -gt "0" ] && are_files "$@" || die "Usage: $(basename "$0") /path/to/file[.gz]..."

# sort input files by modified date
while IFS= read -rd $'\0' FILENAME; do

    # print them to stdout, decompressing on the fly as needed
    case "$FILENAME" in

    *.gz)
        gunzip <"$FILENAME"
        ;;

    *)
        cat "$FILENAME"
        ;;

    esac

done < <(gnu_stat --printf '%Y :%n\0' "$@" | sort -zn | gnu_sed -zE 's/[0-9]+ ://')
