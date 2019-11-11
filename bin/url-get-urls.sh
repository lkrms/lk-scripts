#!/bin/bash
# shellcheck disable=SC1090
# Reviewed: 2019-11-11

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

[ "$#" -eq "1" ] || die "Usage: $(basename "$0") <http://url.to/page-with-urls>"

get_urls_from_url "$@"
