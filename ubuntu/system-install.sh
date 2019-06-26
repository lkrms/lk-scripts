#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/apt-common"

# TODO
#export DEBIAN_FRONTEND=noninteractive

assert_is_ubuntu
assert_not_root
offer_sudo_password_bypass

apt_make_cache_clean

console_message "Upgrading everything that's currently installed..." "" $BLUE

sudo apt-get "${APT_GET_OPTIONS[@]}" -y dist-upgrade || exit 1
[ "$IS_SNAP_INSTALLED" -eq "1" ] && { sudo snap refresh || exit 1; }

# install prequisites and packages that may be needed to bootstrap others
apt_force_install_packages "apt-transport-https aptitude ca-certificates distro-info dmidecode gnupg-agent software-properties-common wget whiptail"

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
apt_register_repository microsoft "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/ubuntu/$DISTRIB_RELEASE/prod $DISTRIB_CODENAME main" "powershell*" Y
apt_register_repository mkvtoolnix "https://mkvtoolnix.download/gpg-pub-moritzbunkus.txt" "deb https://mkvtoolnix.download/ubuntu/ $DISTRIB_CODENAME main" "mkvtoolnix mkvtoolnix-gui"
apt_register_repository nodesource "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" "deb https://deb.nodesource.com/node_8.x $DISTRIB_CODENAME main" "nodejs"
apt_register_repository owncloud-client "https://download.opensuse.org/repositories/isv:ownCloud:desktop/Ubuntu_$DISTRIB_RELEASE/Release.key" "deb http://download.opensuse.org/repositories/isv:/ownCloud:/desktop/Ubuntu_$DISTRIB_RELEASE/ /" "owncloud-client"
apt_register_repository sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "sublime-text"
apt_register_repository typora "https://typora.io/linux/public-key.asc" "deb https://typora.io/linux ./" "typora"
apt_register_repository virtualbox "https://www.virtualbox.org/download/oracle_vbox_2016.asc" "deb https://download.virtualbox.org/virtualbox/debian $DISTRIB_CODENAME contrib" "virtualbox-*"
apt_register_repository vscode "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" "code code-insiders"
apt_register_repository yarn "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn"

# ok, time to get underway
apt_install_packages "package management" "nodejs snapd yarn" N
apt_install_packages "essential utilities" "attr cifs-utils debconf-utils fio hfsprogs hwinfo lftp linux-tools-generic mediainfo net-tools openssh-server ppa-purge pv s-nail screen syslinux-utils tlp tlp-rdw traceroute trickle vim whois"
sudo dmidecode -t system | grep -i ThinkPad &>/dev/null && apt_install_packages "ThinkPad power management" "acpi-call-dkms tp-smapi-dkms"
apt_install_packages "performance monitoring" "atop iotop nethogs powertop sysstat"
apt_install_packages "desktop essentials" "abcde autokey-gtk beets blueman bsd-mailx- code copyq dconf-editor eyed3 filezilla firefox galculator gconf-editor geany ghostwriter gimp git-cola google-chrome-stable handbrake-cli handbrake-gtk inkscape keepassxc lame libdvd-pkg libreoffice meld mkvtoolnix mkvtoolnix-gui owncloud-client qpdfview remmina scribus seahorse speedcrunch sublime-text thunderbird tilda tilix typora usb-creator-gtk vlc"
apt_install_packages "PDF tools" "ghostscript pandoc texlive texlive-luatex"
apt_install_packages "development" 'libapache2-mod-php*-'" build-essential git php php-bcmath php-cli php-curl php-dev php-gd php-gettext php-imagick php-imap php-json php-mbstring php-mcrypt? php-mysql php-pear php-soap php-xdebug php-xml php-xmlrpc python python-dateutil python-dev python-mysqldb python-requests ruby"
apt_package_available powershell && apt_install_packages "PowerShell" "powershell" || apt_install_packages "PowerShell" "powershell-preview"
apt_install_packages "VirtualBox" "virtualbox-6.0"
apt_install_packages "Docker CE" "docker-ce docker-ce-cli containerd.io"

apt_install_deb "https://code-industry.net/public/master-pdf-editor-5.4.30-qt5.amd64.deb"
apt_install_deb "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" Y
apt_install_deb "https://github.com/careteditor/releases-beta/releases/download/4.0.0-rc23/caret-beta.deb"
apt_install_deb "https://go.skype.com/skypeforlinux-64.deb" Y
apt_install_deb "https://release.gitkraken.com/linux/gitkraken-amd64.deb" Y

if [ "$IS_ELEMENTARY_OS" -eq "1" -a "$(lsb_release -sc)" = "juno" ]; then

    # because too many indicators don't play by the rules (see: https://www.reddit.com/r/elementaryos/comments/aghyiq/system_tray/)
    mkdir -p "$HOME/.config/autostart"
    cp -f "/etc/xdg/autostart/indicator-application.desktop" "$HOME/.config/autostart/"
    sed -i 's/^OnlyShowIn.*/OnlyShowIn=Unity;GNOME;Pantheon;/' "$HOME/.config/autostart/indicator-application.desktop"

    apt_install_deb "http://ppa.launchpad.net/elementary-os/stable/ubuntu/pool/main/w/wingpanel-indicator-ayatana/wingpanel-indicator-ayatana_2.0.3+r27+pkg17~ubuntu0.4.1.1_amd64.deb"

    # otherwise the computer will fall asleep at the login screen
    sudo -u lightdm -H dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0 &>/dev/null &&
        sudo -u lightdm -H dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing &>/dev/null ||
        console_message "Unable to apply power settings for 'lightdm' user:" "sleep-inactive-ac-timeout sleep-inactive-ac-type" $RED

fi

apt_process_queue

ALL_PACKAGES=($(printf '%s\n' "${APT_INSTALLED[@]}" | sort | uniq))
console_message "${#APT_INSTALLED[@]} installed $(single_or_plural ${#APT_INSTALLED[@]} "package is" "packages are") managed by $(basename "$0"):" "" $BLUE
ALL_PACKAGES=($(apt_pretty_packages "${ALL_PACKAGES[*]}"))
printf '%s\n' "${ALL_PACKAGES[@]}" | column
