#!/bin/bash
# shellcheck disable=SC1091,SC2015

include='' . lk-bash-load.sh || exit

if lk_is_linux; then
    UNISON_ROOT=$HOME/.unison
elif lk_is_macos; then
    UNISON_ROOT="$HOME/Library/Application Support/Unison"
    lk_include macos
else
    lk_die "${0##*/} not implemented on this platform"
fi

UNISON_PROFILES=("$UNISON_ROOT"/*.prf)
[ ${#UNISON_PROFILES[@]} -gt 0 ] || lk_die "no profiles found"

UNISONLOCALHOSTNAME=${UNISONLOCALHOSTNAME:-$(lk_hostname)}
export UNISONLOCALHOSTNAME

PROCESSED=()
FAILED=()
SKIPPED=()
i=0
for FILE in "${UNISON_PROFILES[@]}"; do
    UNISON_PROFILE=${FILE%.prf}
    UNISON_PROFILE=${UNISON_PROFILE##*/}
    for p in "$(lk_upper_first "$UNISON_PROFILE")" \
        "$UNISON_PROFILE" \
        ".$UNISON_PROFILE" \
        "$UNISON_PROFILE.local"; do
        LOCAL_DIR=$HOME/$p
        [ ! -d "$LOCAL_DIR" ] || break
    done
    [ -d "$LOCAL_DIR" ] &&
        [ ! -e "$LOCAL_DIR/.unison-skip" ] || {
        SKIPPED+=("$UNISON_PROFILE")
        continue
    }
    ! ((i++)) || echo
    lk_console_item "Syncing" "~${LOCAL_DIR#$HOME}"
    _FILE=${FILE%.prf}.$(lk_hostname)~
    lk_file_replace "$_FILE" "$(lk_expand_template -e "$FILE")"
    if unison -source "${_FILE##*/}" \
        -root "$LOCAL_DIR" \
        -auto \
        -logfile "$UNISON_ROOT/unison.$(lk_hostname).$(lk_date_ymd).log" \
        "$@"; then
        PROCESSED+=("$UNISON_PROFILE")
    else
        FAILED+=("$UNISON_PROFILE($?)")
    fi
done

[ ${#SKIPPED[@]} -eq 0 ] || {
    echo
    lk_echo_array SKIPPED |
        lk_console_list "Skipped:" profile profiles
}

[ ${#PROCESSED[@]} -eq 0 ] || {
    echo
    lk_echo_array PROCESSED |
        lk_console_list "Synchronised:" profile profiles \
            "$LK_BOLD$LK_GREEN"
}

[ ${#FAILED[@]} -eq 0 ] || {
    echo
    lk_echo_array FAILED |
        lk_console_list "Failed:" profile profiles \
            "$LK_BOLD$LK_RED"
    echo
    lk_pause
    lk_die ""
}
