#!/bin/bash
# shellcheck disable=SC1090,SC2034

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"
. "$SCRIPT_DIR/../../bash/common-apt"

assert_is_ubuntu
assert_is_server
assert_not_root

{
    offer_sudo_password_bypass

    disable_update_motd

    SUDO_OR_NOT=1
    lk_safe_symlink "$CONFIG_DIR/apt/apt.conf.d/no-install-recommends" \
        "/etc/apt/apt.conf.d/99no-install-recommends"
    unset SUDO_OR_NOT

    # get underway without an immediate index update
    apt_mark_cache_clean

    # ensure all of Ubuntu's repositories are available
    apt_enable_ubuntu_repository main updates
    apt_enable_ubuntu_repository restricted updates
    apt_enable_ubuntu_repository universe updates
    apt_enable_ubuntu_repository multiverse updates

    apt_check_prerequisites

    apt_register_repository \
        docker \
        "https://download.docker.com/linux/ubuntu/gpg" \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable" \
        "origin Docker" \
        "containerd.io docker-ce*"

    apt_register_repository \
        virtualmin \
        "http://software.virtualmin.com/lib/RPM-GPG-KEY-virtualmin-6" \
        "deb http://software.virtualmin.com/vm/6/gpl/apt virtualmin-$DISTRIB_CODENAME main
deb [arch=all] http://software.virtualmin.com/vm/6/gpl/apt virtualmin-universal main" \
        "origin software.virtualmin.com" \
        "webmin"

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
    apt_install_packages "Docker" "containerd.io docker-ce docker-ce-cli"

    apt_process_queue

    lk_install_gnu_commands

    exit

}
