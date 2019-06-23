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

sudo apt-get -qq update && APT_CACHE_DIRTY=0 || exit 1
sudo apt-get -y dist-upgrade || exit 1
[ "$IS_SNAP_INSTALLED" -eq "1" ] && { sudo snap refresh || exit 1; }

# install prequisites and packages that may be needed to bootstrap others
apt_force_install_packages "apt-transport-https aptitude ca-certificates curl distro-info gnupg-agent software-properties-common software-properties-common whiptail"

# ensure all of Ubuntu's repositories are available (including "proposed" archives)
apt_enable_ubuntu_repository main "proposed"
apt_enable_ubuntu_repository restricted "proposed"
apt_enable_ubuntu_repository universe "updates proposed"
apt_enable_ubuntu_repository multiverse "updates proposed"
apt_enable_partner_repository

# prevent "proposed" packages from being installed automatically
if [ ! -e "/etc/apt/preferences.d/proposed-updates" ]; then

    sudo tee "/etc/apt/preferences.d/proposed-updates" >/dev/null <<EOF
Package: *
Pin: release a=${DISTRIB_CODENAME}-proposed
Pin-Priority: 400
EOF

fi

# register PPAs (note: this doesn't add them to the system straightaway; they are added on-demand if/when the relevant packages are actually installed)
apt_register_ppa "caffeine-developers/ppa" "caffeine"
apt_register_ppa "eosrei/fonts" "fonts-twemoji-svginot"
apt_register_ppa "hluk/copyq" "copyq"
apt_register_ppa "inkscape.dev/stable" "inkscape"
apt_register_ppa "linrunner/tlp" "tlp"
apt_register_ppa "phoerious/keepassxc" "keepassxc"
apt_register_ppa "scribus/ppa" "scribus"
apt_register_ppa "stebbins/handbrake-releases" "handbrake-cli handbrake-gtk"
apt_register_ppa "wereturtle/ppa" "ghostwriter"

# ditto for non-PPA repositories
apt_register_repository docker "https://download.docker.com/linux/ubuntu/gpg" "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable" "docker-ce* containerd.io"
apt_register_repository google-chrome "https://dl.google.com/linux/linux_signing_key.pub" "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" "google-chrome-stable"
apt_register_repository microsoft "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/ubuntu/$DISTRIB_RELEASE/prod $DISTRIB_CODENAME main" "powershell*"
apt_register_repository mkvtoolnix "https://mkvtoolnix.download/gpg-pub-moritzbunkus.txt" "deb https://mkvtoolnix.download/ubuntu/ $DISTRIB_CODENAME main" "mkvtoolnix mkvtoolnix-gui"
apt_register_repository nodesource "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" "deb https://deb.nodesource.com/node_8.x $DISTRIB_CODENAME main" "nodejs"
apt_register_repository owncloud-client "https://download.opensuse.org/repositories/isv:ownCloud:desktop/Ubuntu_$DISTRIB_RELEASE/Release.key" "deb http://download.opensuse.org/repositories/isv:/ownCloud:/desktop/Ubuntu_$DISTRIB_RELEASE/ /" "owncloud-client"
apt_register_repository sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "sublime-text"
apt_register_repository typora "https://typora.io/linux/public-key.asc" "deb https://typora.io/linux ./" "typora"
apt_register_repository virtualbox "https://www.virtualbox.org/download/oracle_vbox_2016.asc" "deb https://download.virtualbox.org/virtualbox/debian $DISTRIB_CODENAME contrib" "virtualbox-*"
apt_register_repository yarn "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn"

# ok, time to get underway
apt_install_packages "package management" "nodejs yarn" N Y
apt_install_packages "utilities" "attr cifs-utils debconf-utils fio hfsprogs hwinfo lftp net-tools openssh-server ppa-purge pv s-nail screen syslinux-utils traceroute trickle vim whois" Y Y
apt_install_packages "performance monitoring" "atop iotop nethogs powertop sysstat" Y Y
apt_install_packages "PDF tools" "ghostscript pandoc texlive texlive-luatex" Y Y
apt_install_packages "development" "build-essential git php php-bcmath php-cli php-curl php-dev php-gd php-gettext php-imagick php-imap php-json php-mbstring php-mcrypt php-mysql php-pear php-soap php-xdebug php-xml php-xmlrpc python python-dateutil python-dev python-mysqldb python-requests ruby" Y Y
apt_install_packages "VirtualBox" "virtualbox-6.0" Y Y
apt_install_packages "Docker CE" "docker-ce docker-ce-cli containerd.io" Y Y

apt_process_queue

