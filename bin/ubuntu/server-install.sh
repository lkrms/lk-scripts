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

    apt_apply_preferences suppress-bsd-mailx suppress-libapache2-mod-php suppress-virt-viewer suppress-youtube-dl withhold-proposed-packages

    # get underway without an immediate index update
    apt_mark_cache_clean

    # ensure all of Ubuntu's repositories are available (including "backports" and "proposed" archives)
    apt_enable_ubuntu_repository main updates backports proposed
    apt_enable_ubuntu_repository restricted updates backports proposed
    apt_enable_ubuntu_repository universe updates backports proposed
    apt_enable_ubuntu_repository multiverse updates backports proposed

    apt_check_prerequisites

    brew_check
    brew_mark_cache_clean
    brew_check_taps

    apt_register_repository docker "https://download.docker.com/linux/ubuntu/gpg" "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable" "origin Docker" "containerd.io docker-ce*"
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

    is_virtual || apt_install_packages "QEMU/KVM" "libvirt-bin libvirt-doc qemu-kvm virtinst"

    apt_install_packages "Webmin" "webmin"
    apt_install_packages "Samba server" "samba"
    apt_install_packages "DHCP server" "dnsmasq"
    apt_install_packages "PPPoE client" "pppoe pppoeconf wide-dhcpv6-client"
    apt_install_packages "Squid proxy server" "squid"
    apt_install_packages "APT proxy server" "apt-cacher-ng"
    apt_install_packages "BitTorrent client" "transmission-cli"
    apt_install_packages "youtube-dl dependencies" "ffmpeg rtmpdump"
    apt_install_packages "Docker" "containerd.io docker-ce docker-ce-cli"

    brew_queue_formulae "Unison" "unison"
    brew_queue_formulae "Shell script formatter" "shfmt"

    apt_process_queue

    brew_process_queue

    lk_install_gnu_commands

    exit

}
