#!/bin/bash

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common" || exit 1

assert_is_ubuntu
assert_not_root

# TODO
#export DEBIAN_FRONTEND=noninteractive

console_message "Upgrading everything that's currently installed..." "" $BLUE

sudo apt-get -qq update || exit 1
sudo apt-get -y dist-upgrade || exit 1
[ "$IS_SNAP_INSTALLED" -eq "1" ] && { sudo snap refresh || exit 1; }

apt_force_install_packages "aptitude software-properties-common distro-info whiptail"
