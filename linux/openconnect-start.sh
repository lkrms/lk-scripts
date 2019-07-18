#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_not_root
assert_command_exists openconnect
assert_command_exists secret-tool

USAGE="Usage: $(basename "$0") <username@vpn.host.com> [openconnect-option...]"

if [ "$#" -lt 1 ]; then

    die "$USAGE"

fi

VPN_HOST="${1##*@}"
VPN_USER="${1%@*}"

if [ -z "$VPN_HOST" ] || [ -z "$VPN_USER" ]; then

    die "$USAGE"

fi

shift

OPENCONNECT_OPTIONS=(nohup openconnect)
OPENCONNECT_OPTIONS+=("$@")

if ! VPN_PASSWORD="$(secret-tool lookup "${VPN_USER}@${VPN_HOST}" openconnect-password)"; then

    echoc "No password for ${BOLD}${VPN_USER}@${VPN_HOST}${RESET} found in keyring. Please provide it now."
    secret-tool store --label="openconnect password for $VPN_HOST" "${VPN_USER}@${VPN_HOST}" openconnect-password
    VPN_PASSWORD="$(secret-tool lookup "${VPN_USER}@${VPN_HOST}" openconnect-password)" || VPN_PASSWORD=

fi

if ! array_search "--protocol*" OPENCONNECT_OPTIONS >/dev/null; then

    OPENCONNECT_OPTIONS+=(--protocol gp)

fi

if ! array_search "--dump" OPENCONNECT_OPTIONS >/dev/null; then

    OPENCONNECT_OPTIONS+=(--dump)

fi

if ! array_search "-v*" OPENCONNECT_OPTIONS >/dev/null; then

    OPENCONNECT_OPTIONS+=(-vvv)

fi

if [ -n "$VPN_PASSWORD" ] && ! array_search "--passwd-on-stdin" OPENCONNECT_OPTIONS >/dev/null; then

    OPENCONNECT_OPTIONS+=(--passwd-on-stdin)

fi

OPENCONNECT_OPTIONS+=(-u "$VPN_USER" "$VPN_HOST")

LOG_FILE="$RS_LOG_DIR/openconnect-$(get_yyyymmddhhmmss).log"

if [ -n "$VPN_PASSWORD" ]; then

    echo "$VPN_PASSWORD" | sudo bash -c "${OPENCONNECT_OPTIONS[*]} >$LOG_FILE 2>&1" &

else

    sudo bash -c "${OPENCONNECT_OPTIONS[*]} >$LOG_FILE 2>&1" &

fi

if [ -t 1 ]; then

    echo "openconnect($!) started: ${LOG_FILE}"

fi
