#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/common"
. "$SCRIPT_DIR/common-dev"

assert_not_root

if command_exists apt-get; then

    . "$SCRIPT_DIR/common-apt"

    apt_upgrade_all

fi

if command_exists brew; then

    . "$SCRIPT_DIR/common-homebrew"

    brew_upgrade_all

    brew_formula_installed node || ! brew_formula_installed node@8 || brew link --force --overwrite node@8

fi

if command_exists snap; then

    sudo snap refresh

fi

dev_update_packages
