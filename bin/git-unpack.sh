#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/common-git"

shopt -s nullglob

lk_assert_command_exists git
lk_assert_command_exists realpath

DRYRUN_BY_DEFAULT=Y
dryrun_message

USAGE="Usage: $(basename "$0") [/path/to/repo]"
REPO_ROOT="$(realpath "${1:-$PWD}" 2>/dev/null)" || lk_die "$USAGE"
[ "$#" -le "1" ] && git_is_dir_working_root "$REPO_ROOT" || lk_die "$USAGE"

cd "$REPO_ROOT"

PACKS=(".git/objects/pack/"*.idx)
PACK_COUNT="${#PACKS[@]}"

[ "$PACK_COUNT" -gt "0" ] || {
    lk_console_log "No packs in $REPO_ROOT"
    exit
}

i=0

for PACK in "${PACKS[@]}"; do

    ((++i))
    lk_console_item "Verifying pack ($i of $PACK_COUNT):" "$(basename "${PACK%.idx}")"

    [ -e "${PACK%.idx}.pack" ] && git verify-pack "$PACK" || lk_die "verify-pack failed for $PWD/$PACK"

done

lk_console_message "$PACK_COUNT $(lk_maybe_plural "$PACK_COUNT" pack packs) verified in $REPO_ROOT" "$LK_GREEN"

PACK_ROOT="$(lk_mktemp_dir)"

lk_console_message "Moving $PACK_COUNT $(lk_maybe_plural "$PACK_COUNT" pack packs)"

for PACK in "${PACKS[@]}"; do

    maybe_dryrun mv -vn "${PACK%.idx}"* "$PACK_ROOT/" || lk_die

done

lk_console_message "Unpacking $PACK_COUNT $(lk_maybe_plural "$PACK_COUNT" pack packs) in $REPO_ROOT"

i=0

for PACK in "${PACKS[@]}"; do

    ((++i))
    lk_console_item "Unpacking pack ($i of $PACK_COUNT):" "$(basename "${PACK%.idx}")"

    if ! is_dryrun; then

        git unpack-objects <"$PACK_ROOT/$(basename "${PACK%.idx}.pack")" || lk_die

    else

        maybe_dryrun git unpack-objects '<'"$PACK_ROOT/$(basename "${PACK%.idx}.pack")" || lk_die

    fi

    ! lk_command_exists trash-put || maybe_dryrun trash-put "$PACK_ROOT/$(basename "${PACK%.idx}.pack")"

done

! lk_command_exists trash-put || maybe_dryrun trash-put "$PACK_ROOT"
