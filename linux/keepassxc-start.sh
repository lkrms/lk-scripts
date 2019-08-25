#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_not_root
assert_command_exists keepassxc
assert_command_exists secret-tool

USAGE="Usage: $(basename "$0") </path/to/database> [/path/to/key_file]"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then

    die "$USAGE"

fi

DATABASE_PATH="$1"
KEY_PATH="${2:-}"

[ -f "$DATABASE_PATH" ] || die "$USAGE"

KEEPASSXC_OPTIONS=()

if [ -n "$KEY_PATH" ]; then

    [ -f "$KEY_PATH" ] || die "$USAGE"

    KEEPASSXC_OPTIONS+=(--keyfile "$KEY_PATH")

fi

if ! KEEPASSXC_PASSWORD="$(secret-tool lookup "$DATABASE_PATH" keepassxc-password)"; then

    echoc "No password for ${BOLD}${DATABASE_PATH}${RESET} found in keyring. Please provide it now."
    secret-tool store --label="KeePassXC password for $DATABASE_PATH" "$DATABASE_PATH" keepassxc-password
    KEEPASSXC_PASSWORD="$(secret-tool lookup "$DATABASE_PATH" keepassxc-password)" || KEEPASSXC_PASSWORD=

fi

if [ -n "$KEEPASSXC_PASSWORD" ]; then

    KEEPASSXC_OPTIONS+=(--pw-stdin)
    echo "$KEEPASSXC_PASSWORD" | keepassxc "${KEEPASSXC_OPTIONS[@]}" "$DATABASE_PATH"

else

    keepassxc "${KEEPASSXC_OPTIONS[@]}" "$DATABASE_PATH"

fi
