#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/common-git"

shopt -s nullglob

assert_command_exists git
assert_git_dir_is_working_root

DRYRUN_BY_DEFAULT=Y
dryrun_message

PACKS=(".git/objects/pack/"*.idx)
PACK_COUNT="${#PACKS[@]}"

[ "$PACK_COUNT" -gt "0" ] || die_happy "No packs in this repository"

i=0

for PACK in "${PACKS[@]}"; do

    ((++i))
    console_message "Verifying pack ($i of $PACK_COUNT):" "$(basename "${PACK%.idx}")" "$CYAN"

    [ -e "${PACK%.idx}.pack" ] && git verify-pack "$PACK" || die "verify-pack failed for $PWD/$PACK"

done

console_message "$PACK_COUNT $(single_or_plural "$PACK_COUNT" pack packs) verified" "" "$GREEN"

PACK_ROOT="$(create_temp_dir Y)"

console_message "Moving $PACK_COUNT $(single_or_plural "$PACK_COUNT" pack packs)" "" "$CYAN"

for PACK in "${PACKS[@]}"; do

    maybe_dryrun mv -vn "${PACK%.idx}"* "$PACK_ROOT/" || die

done

console_message "Unpacking $PACK_COUNT $(single_or_plural "$PACK_COUNT" pack packs)" "" "$CYAN"

i=0

for PACK in "${PACKS[@]}"; do

    ((++i))
    console_message "Unpacking pack ($i of $PACK_COUNT):" "$(basename "${PACK%.idx}")" "$CYAN"

    if ! is_dryrun; then

        git unpack-objects <"$PACK_ROOT/$(basename "${PACK%.idx}.pack")" || die

    else

        maybe_dryrun git unpack-objects '<'"$PACK_ROOT/$(basename "${PACK%.idx}.pack")" || die

    fi

done
