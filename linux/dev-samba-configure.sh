#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

assert_is_linux
assert_command_exists testparm

SAMBA_DEFAULT_CONF_PATH="${SAMBA_DEFAULT_CONF_PATH:-/usr/share/samba/smb.conf}"

SETTINGS=()

[ -z "${SAMBA_WORKGROUP:-}" ] || SETTINGS+=("workgroup = $SAMBA_WORKGROUP")

# disable printing
SETTINGS+=(
    'load printers = No'
    'printcap name = /dev/null'
    'disable spoolss = Yes'
    'printing = bsd'
)

TESTPARM_EXTRA=()

if has_argument --reset; then

    [ -e "$SAMBA_DEFAULT_CONF_PATH" ] || die "Unable to reset Samba settings without defaults file ($SAMBA_DEFAULT_CONF_PATH)"
    TESTPARM_EXTRA+=("$SAMBA_DEFAULT_CONF_PATH")
    APPEND_AFTER=$'

[homes]
\tavailable = No
\tbrowseable = No
\tread only = No
\tvalid users = %S
\twide links = Yes'

else

    CURRENT_GLOBAL="$(testparm --suppress-prompt --section-name global 2>/dev/null)" || die "Unable to load current Samba settings (consider \"$(basename "$0") --reset\")"
    CURRENT_ALL_SECTIONS="$(testparm --suppress-prompt 2>/dev/null)"
    APPEND_AFTER="$(comm --nocheck-order -13 <(echo "$CURRENT_GLOBAL") <(echo "$CURRENT_ALL_SECTIONS"))"

fi

TEMP_CONF="$(create_temp_file N)"
DELETE_ON_EXIT+=("$TEMP_CONF")

# create a new configuration file, based on the current (or default) configuration
# 1. [global]
testparm --suppress-prompt --section-name global "${TESTPARM_EXTRA[@]}" >"$TEMP_CONF" 2>/dev/null || die "Unable to load default Samba settings"

# 2. add [global] settings (later settings override earlier ones)
printf '\t%s\n' "${SETTINGS[@]}" >>"$TEMP_CONF"

# 3. add current (or default) services
[ -z "$APPEND_AFTER" ] || echo "$APPEND_AFTER" >>"$TEMP_CONF"

# finally, replace the live configuration file
if CONF="$(testparm --suppress-prompt "$TEMP_CONF" 2>/dev/null)"; then

    sudo_function move_file_delete_link "/etc/samba/smb.conf"

    echo "$CONF" | sudo tee "/etc/samba/smb.conf" >/dev/null

else

    die "Error: unable to apply Samba configuration"

fi
