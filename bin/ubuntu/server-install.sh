#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"
. "$SCRIPT_DIR/../../bash/common-apt"
. "$SCRIPT_DIR/../../bash/common-homebrew"

assert_is_ubuntu
assert_is_server
assert_not_root

# allow this script to be changed while it's running
{
    offer_sudo_password_bypass

    disable_update_motd

    apt_apply_preferences suppress-bsd-mailx suppress-libapache2-mod-php withhold-proposed-packages

    # get underway without an immediate index update
    apt_mark_cache_clean

    # ensure all of Ubuntu's repositories are available (including "backports" and "proposed" archives)
    apt_enable_ubuntu_repository main "updates backports proposed"
    apt_enable_ubuntu_repository restricted "updates backports proposed"
    apt_enable_ubuntu_repository universe "updates backports proposed"
    apt_enable_ubuntu_repository multiverse "updates backports proposed"

    apt_check_prerequisites

    apt_register_repository webmin "http://www.webmin.com/jcameron-key.asc" "deb https://download.webmin.com/download/repository sarge contrib" "origin Jamie Cameron" "webmin"

    APT_ESSENTIALS+=(
        python-pip
        python3-pip

        # npm
        nodejs
        yarn

        # composer
        php-cli
    )

    apt_check_essentials

    apt_install_packages "Webmin" "webmin"

    apt_process_queue

    exit

}
