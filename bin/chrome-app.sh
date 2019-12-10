#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_not_root

[ "$#" -eq "2" ] || die "Usage: $(basename "$0") url instancename [chrome_arg ...]"

URL="$1"
INSTANCE_NAME="$2"
shift 2

[ -d "${HOME:-}" ] || die "HOME not set"

google-chrome --user-data-dir="$HOME/.config/$INSTANCE_NAME" --no-first-run --enable-features=OverlayScrollbar --app="$URL" "$@"
