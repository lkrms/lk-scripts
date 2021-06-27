#!/bin/bash

. lk-bash-load.sh || exit

shopt -s nullglob

if lk_is_linux; then
    UNISON_ROOT=~/.unison
elif lk_is_macos; then
    UNISON_ROOT=~/"Library/Application Support/Unison"
    lk_include macos
else
    lk_die "${0##*/} not implemented on this platform"
fi

UNISON_PROFILES=()
while [ $# -gt 0 ] && [[ ! $1 =~ ^- ]]; do
    FILE=$UNISON_ROOT/${1%.prf}
    FILE=$(lk_first_existing "$FILE.prf.template" "$FILE.prf") ||
        lk_die "profile not found: $1"
    UNISON_PROFILES+=("$FILE")
    shift
done

[ ${#UNISON_PROFILES[@]} -gt 0 ] ||
    UNISON_PROFILES=("$UNISON_ROOT"/*.prf{.template,})
[ ${#UNISON_PROFILES[@]} -gt 0 ] || lk_die "no profiles found"

UNISONLOCALHOSTNAME=${UNISONLOCALHOSTNAME:-$(lk_hostname)}
export UNISONLOCALHOSTNAME

PROCESSED=()
FAILED=()
SKIPPED=()
i=0
for FILE in "${UNISON_PROFILES[@]}"; do
    UNISON_PROFILE=${FILE##*/}
    [ "$UNISON_PROFILE" != default.prf ] || continue
    UNISON_PROFILE=${UNISON_PROFILE%.template}
    UNISON_PROFILE=${UNISON_PROFILE%.prf}
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
    ! ((i++)) || lk_console_blank
    lk_console_item "Syncing" "~${LOCAL_DIR#$HOME}"
    if [[ $FILE == *.prf.template ]]; then
        _FILE=${FILE%.prf.template}.$(lk_hostname)~
        lk_file_replace "$_FILE" "$(lk_expand_template -e "$FILE")"
    else
        _FILE=$FILE
    fi
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
    ! ((i++)) || lk_console_blank
    lk_echo_array SKIPPED |
        lk_console_list "Skipped:" profile profiles
}

[ ${#PROCESSED[@]} -eq 0 ] || {
    ! ((i++)) || lk_console_blank
    lk_echo_array PROCESSED |
        lk_console_list "Synchronised:" profile profiles \
            "$LK_BOLD$LK_GREEN"
}

[ ${#FAILED[@]} -eq 0 ] || {
    ! ((i++)) || lk_console_blank
    lk_echo_array FAILED |
        lk_console_list "Failed:" profile profiles \
            "$LK_BOLD$LK_RED"
    lk_console_blank
    lk_pause
    lk_die ""
}
