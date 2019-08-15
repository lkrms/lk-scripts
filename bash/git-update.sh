#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common-dev"

assert_command_exists git

git_get_code_roots

[ "${#CODE_ROOTS[@]}" -gt "0" ] || die "Usage: $(basename "$0") [/code/root...]"

REPOS=()

for CODE_ROOT in "${CODE_ROOTS[@]}"; do

    while IFS= read -rd $'\0' PATH; do

        REPOS+=($PATH)

    done < <(find "$CODE_ROOT" -maxdepth 3 -type d -name .git -print0 | sort -z)

done

