#!/bin/bash

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common" || exit 1

assert_is_ubuntu_lts
assert_not_root

console_message "Upgrading everything that's currently installed..." "" $BLUE

sudo apt-get update || exit 1
sudo apt-get -y dist-upgrade || exit 1
[ "$IS_SNAP_INSTALLED" -eq "1" ] && { sudo snap refresh || exit 1; }

if ! apt_package_installed software-properties-common; then

    console_message "Installing software-properties-common to get add-apt-repository..." "" $BLUE

    sudo apt-get -y install software-properties-common || exit 1

fi
