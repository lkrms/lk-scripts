#!/bin/bash
# shellcheck disable=SC1090
# Reviewed 2019-11-21

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../bash/common"

[ "$#" -eq "0" ] || {
    DRYRUN_BY_DEFAULT=Y
    dryrun_message
}

shopt -s nullglob

case "$PLATFORM" in

linux | wsl)
    UNISON_PROFILES=("$HOME/.unison/"*.prf)
    ;;

mac)
    UNISON_PROFILES=("$HOME/Library/Application Support/Unison/"*.prf)
    ;;

*)
    die "$(basename "$0") is not supported on this platform"
    ;;

esac

[ "${#UNISON_PROFILES[@]}" -gt "0" ] || die "No Unison profiles found"

pushd "$HOME" >/dev/null || die

for UNISON_PROFILE in "${UNISON_PROFILES[@]}"; do

    UNISON_PROFILE="$(basename "${UNISON_PROFILE%.prf}")"

    case "$UNISON_PROFILE" in

    temp)
        LOCAL_DIR="Temp.local"
        ;;

    *)
        LOCAL_DIR="$(upper_first "$UNISON_PROFILE")"
        ;;

    esac

    [ -d "$LOCAL_DIR" ] || continue

    maybe_dryrun unison "$UNISON_PROFILE" -auto "$@" || die

done

popd >/dev/null
