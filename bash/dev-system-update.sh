#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/common"
. "$SCRIPT_DIR/common-dev"

lk_assert_not_root

if lk_command_exists apt-get; then

    . "$SCRIPT_DIR/common-apt"

    apt_upgrade_all

fi

if lk_command_exists brew; then

    . "$SCRIPT_DIR/common-homebrew"

    brew_upgrade_all

    ! lk_is_macos || brew_formula_installed node || ! brew_formula_installed node@8 || {
        PATH="/usr/local/opt/node@8/bin:$PATH" /usr/local/opt/node@8/bin/npm update -g
    }

fi

if lk_command_exists snap; then

    sudo snap refresh

fi

dev_update_packages
