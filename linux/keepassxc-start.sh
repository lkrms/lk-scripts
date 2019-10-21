#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

assert_not_root
assert_command_exists keepassxc
assert_command_exists secret-tool

USAGE="Usage: $(basename "$0") </path/to/database> [/path/to/another/database...]"

[ "$#" -gt "0" ] || die "$USAGE"

PASSWORDS=()

for DATABASE_PATH in "$@"; do

    [ -f "$DATABASE_PATH" ] || die "$USAGE"

    if ! PASSWORD="$(secret-tool lookup "$DATABASE_PATH" keepassxc-password)"; then

        echoc "No password for ${BOLD}${DATABASE_PATH}${RESET} found in keyring. Please provide it now."
        secret-tool store --label="KeePassXC password for $DATABASE_PATH" "$DATABASE_PATH" keepassxc-password
        PASSWORD="$(secret-tool lookup "$DATABASE_PATH" keepassxc-password)" || PASSWORD=

    fi

    PASSWORDS+=("$PASSWORD")

done

IFS=$'\n\n\n'
nohup keepassxc --pw-stdin "$@" >/dev/null 2>&1 <<<"${PASSWORDS[*]}" &
