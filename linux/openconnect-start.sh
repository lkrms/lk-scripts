#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_not_root
assert_command_exists openconnect
assert_command_exists vpn-slice
assert_command_exists secret-tool

USAGE="Usage: $(basename "$0") <username@vpn.host.com> [\"route1 route2...\" [openconnect-option...]]"

if [ "$#" -lt 1 ]; then

    die "$USAGE"

fi

VPN_HOST="${1##*@}"
VPN_USER="${1%@*}"
HOSTS_TO_ROUTE="${2:-}"

if [ -z "$VPN_HOST" ] || [ -z "$VPN_USER" ]; then

    die "$USAGE"

fi

shift
shift || true

if pgrep -x openconnect >/dev/null; then

    die "openconnect is already running"

fi

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

if ! array_search "-s" OPENCONNECT_OPTIONS >/dev/null && ! array_search "--script" OPENCONNECT_OPTIONS >/dev/null; then

    if [ -z "$HOSTS_TO_ROUTE" ]; then

        OPENCONNECT_OPTIONS+=(--script "'vpn-slice -IS'")

    else

        OPENCONNECT_OPTIONS+=(--script "'vpn-slice $HOSTS_TO_ROUTE'")

    fi

fi

if ! array_search "--dump-http-traffic" OPENCONNECT_OPTIONS >/dev/null; then

    OPENCONNECT_OPTIONS+=(--dump-http-traffic)

fi

if ! array_search "-v*" OPENCONNECT_OPTIONS >/dev/null; then

    OPENCONNECT_OPTIONS+=(-vvv)

fi

if [ -n "$VPN_PASSWORD" ] && ! array_search "--passwd-on-stdin" OPENCONNECT_OPTIONS >/dev/null; then

    OPENCONNECT_OPTIONS+=(--passwd-on-stdin)

fi

OPENCONNECT_OPTIONS+=(-u "$VPN_USER" "$VPN_HOST")

LOG_FILE="$LOG_DIR/openconnect-$(date_get_ymdhms).log"

if [ -n "$VPN_PASSWORD" ]; then

    echo "$VPN_PASSWORD" | sudo -b bash -c "${OPENCONNECT_OPTIONS[*]} >$LOG_FILE 2>&1"

else

    sudo -b bash -c "${OPENCONNECT_OPTIONS[*]} >$LOG_FILE 2>&1"

fi

if [ -t 1 ]; then

    echo "openconnect started: ${LOG_FILE}"
    echo
    echoc "After 5 seconds, ${LOG_FILE} will be tailed. Terminate with Ctrl-C. Your connection will continue in the background." "$BOLD" "$YELLOW"

    sleep 5

    tail -n +1 -f "${LOG_FILE}"

fi
