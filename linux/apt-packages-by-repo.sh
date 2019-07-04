#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/apt-common"

assert_not_root

command_exists aptitude || apt_force_install_packages "aptitude"

file_to_array <(apt-cache policy | grep -oP '(?<=(,|\s)o=).*?(?=,)' | sort | uniq)

ORIGINS=("${FILE_TO_ARRAY[@]}")

for ORIGIN in "${ORIGINS[@]}"; do

    echoc "Packages from ${ORIGIN}:" $BOLD >&2
    aptitude search "?origin($ORIGIN) ?installed" -F "%?p %?v %?O" || true

done

echoc "Packages with no origin:" $BOLD >&2
aptitude search "?obsolete" -F "%?p %?v %?O" || true
