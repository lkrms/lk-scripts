#!/bin/bash

# shellcheck disable=SC1091
. /dev/stdin <<<"$(
    set -euo pipefail

    SCRIPT_PATH="${BASH_SOURCE[0]}"
    if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

    # shellcheck source=bash/common
    . "$SCRIPT_DIR/bash/common"

    variable_exists "ADD_TO_PATH" || ADD_TO_PATH=()

    ADD_TO_PATH+=("$ROOT_DIR" "$ROOT_DIR/bash" "$ROOT_DIR/synergy")

    [ "$IS_MACOS" -eq "1" ] && ADD_TO_PATH+=("$ROOT_DIR/macos")
    [ "$IS_LINUX" -eq "1" ] && ADD_TO_PATH+=("$ROOT_DIR/linux")
    [ "$IS_UBUNTU" -eq "1" ] && ADD_TO_PATH+=("$ROOT_DIR/ubuntu")

    ADD_TO_PATH+=("$HOME/.local/bin")
    ADD_TO_PATH+=("$HOME/.composer/vendor/bin")
    ADD_TO_PATH+=("$HOME/.config/composer/vendor/bin")

    for KEY in "${!ADD_TO_PATH[@]}"; do

        if [[ ":$PATH:" == *":${ADD_TO_PATH[$KEY]}:"* ]] || [ ! -d "${ADD_TO_PATH[$KEY]}" ]; then

            unset "ADD_TO_PATH[$KEY]"

        fi

    done

    # shellcheck disable=SC2016
    if [ "${#ADD_TO_PATH[@]}" -gt "0" ]; then

        echo 'export PATH="$PATH:'"$(array_join_by ":" "${ADD_TO_PATH[@]}")"'"'

    fi

    echo "export LINAC_ROOT_DIR=\"$ROOT_DIR\""

    command_exists gtk-launch && echo 'alias gtk-debug="GTK_DEBUG=interactive "'
    command_exists xdg-open && echo 'alias open=xdg-open'

)"

function _latest() {

    local TYPE="${1:-}" COMMAND

    [ "${#TYPE}" -eq "1" ] && shift || TYPE="f"

    COMMAND=(find . -xdev \()

    [ "$#" -eq "0" ] || COMMAND+=(\( "$@" -prune \) -o)

    COMMAND+=(\( -type "$TYPE" -print0 \) \))

    "${COMMAND[@]}" | xargs -0 stat --format '%Y :%y %n' | sort -nr | cut -d: -f2- | less

}

# files after excluding .git directories
function latest() {
    _latest f -type d -name .git
}

# directories after excluding .git directories
function latest-dir() {
    _latest d -type d -name .git
}

# all files
function latest-all() {
    _latest f
}
