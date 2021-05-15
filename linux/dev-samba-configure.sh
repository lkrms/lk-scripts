#!/bin/bash
# shellcheck disable=SC1090

include='' . lk-bash-load.sh || exit

lk_assert_is_linux
lk_assert_command_exists testparm

SAMBA_DEFAULT_CONF_PATH="${SAMBA_DEFAULT_CONF_PATH:-/usr/share/samba/smb.conf}"

SETTINGS=(
    'create mask = 0777'
    'directory mask = 0777'
    'map archive = No'
)

[ -z "${SAMBA_WORKGROUP-}" ] || SETTINGS+=("workgroup = $SAMBA_WORKGROUP")

# disable printing
SETTINGS+=(
    'load printers = No'
    'printcap name = /dev/null'
    'disable spoolss = Yes'
    'printing = bsd'
)

# improve support for Apple clients
SETTINGS+=(
    'server min protocol = SMB2'
    'ea support = Yes'
    'vfs objects = catia fruit streams_xattr'
    'aio read size = 1'
    'aio write size = 1'
    'use sendfile = Yes'
    'delete veto files = Yes'
    'fruit:wipe_intentionally_left_blank_rfork = Yes'
    'fruit:delete_empty_adfiles = Yes'
)

TESTPARM_EXTRA=()

if lk_has_arg --reset; then

    [ -e "$SAMBA_DEFAULT_CONF_PATH" ] || lk_die "Unable to reset Samba settings without defaults file ($SAMBA_DEFAULT_CONF_PATH)"
    TESTPARM_EXTRA+=("$SAMBA_DEFAULT_CONF_PATH")
    APPEND_AFTER=$'

[homes]
\tavailable = No
\tbrowseable = No
\tread only = No
\tvalid users = %S
\twide links = Yes'

else

    CURRENT_GLOBAL="$(testparm --suppress-prompt --section-name global 2>/dev/null)" || lk_die "Unable to load current Samba settings (consider \"$(basename "$0") --reset\")"
    CURRENT_ALL_SECTIONS="$(testparm --suppress-prompt 2>/dev/null)"
    APPEND_AFTER="$(comm --nocheck-order -13 <(echo "$CURRENT_GLOBAL") <(echo "$CURRENT_ALL_SECTIONS"))"

fi

TEMP_CONF="$(lk_mktemp_file)"
lk_delete_on_exit "$TEMP_CONF"

# create a new configuration file, based on the current (or default) configuration
# 1. [global]
testparm --suppress-prompt --section-name global "${TESTPARM_EXTRA[@]}" >"$TEMP_CONF" 2>/dev/null || lk_die "Unable to load default Samba settings"

# 2. add [global] settings (later settings override earlier ones)
printf '\t%s\n' "${SETTINGS[@]}" >>"$TEMP_CONF"

# 3. add current (or default) services
[ -z "$APPEND_AFTER" ] || echo "$APPEND_AFTER" >>"$TEMP_CONF"

# finally, replace the live configuration file
if CONF="$(testparm --suppress-prompt "$TEMP_CONF" 2>/dev/null)"; then

    [ ! -e "/etc/samba/smb.conf" ] || sudo mv -fv "/etc/samba/smb.conf" "/etc/samba/smb.$(lk_timestamp).conf.bak"

    echo "$CONF" | sudo tee "/etc/samba/smb.conf" >/dev/null

else

    lk_die "Error: unable to apply Samba configuration"

fi
