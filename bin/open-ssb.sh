#!/bin/bash
# shellcheck disable=SC1091,SC2015

include='' . lk-bash-load.sh || exit

lk_assert_not_root

[ $# -ge 1 ] &&
    [[ $1 =~ ^https?:\/\/([^/]+)(\/.*)?$ ]] || lk_usage "\
Usage: ${0##*/} URL [CHROME_ARG...]"

INSTANCE_NAME=${BASH_REMATCH[1]}_${BASH_REMATCH[2]}
INSTANCE_NAME=${INSTANCE_NAME//\//_}
[[ ! $INSTANCE_NAME =~ ((.*)([^_]|^))_+$ ]] ||
    INSTANCE_NAME=${BASH_REMATCH[1]}

COMMAND=$(lk_command_first_existing \
    chromium \
    google-chrome-stable \
    google-chrome chrome) || lk_die "Chrome not found"

"$COMMAND" \
    --user-data-dir="$HOME/.config/$INSTANCE_NAME" \
    --no-first-run \
    --enable-features=OverlayScrollbar \
    --app="$1" \
    "${@:2}"
