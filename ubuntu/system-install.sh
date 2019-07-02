#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

. "$SCRIPT_DIR/../bash/common"
. "$SCRIPT_DIR/../bash/apt-common"

assert_is_ubuntu
assert_not_server
assert_not_root

offer_sudo_password_bypass

apt_make_cache_clean

# install prequisites and packages that may be needed to bootstrap others
apt_force_install_packages "apt-transport-https aptitude debconf-utils distro-info dmidecode snapd software-properties-common whiptail"

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

# seed debconf database with answers
sudo debconf-set-selections <<EOF
libc6 libraries/restart-without-asking boolean true
libpam0g libraries/restart-without-asking boolean true
EOF

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
apt_register_repository mongodb-org-4.0 "https://www.mongodb.org/static/pgp/server-4.0.asc" "deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" "mongodb-org"
apt_register_repository nodesource "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" "deb https://deb.nodesource.com/node_8.x $DISTRIB_CODENAME main" "nodejs"
apt_register_repository owncloud-client "https://download.opensuse.org/repositories/isv:ownCloud:desktop/Ubuntu_$DISTRIB_RELEASE/Release.key" "deb http://download.opensuse.org/repositories/isv:/ownCloud:/desktop/Ubuntu_$DISTRIB_RELEASE/ /" "owncloud-client"
apt_register_repository sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "sublime-text"
apt_register_repository typora "https://typora.io/linux/public-key.asc" "deb https://typora.io/linux ./" "typora"
apt_register_repository virtualbox "https://www.virtualbox.org/download/oracle_vbox_2016.asc" "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $DISTRIB_CODENAME contrib" "virtualbox-*"
apt_register_repository vscode "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" "code code-insiders"
apt_register_repository yarn "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "yarn"

apt_install_packages "essential utilities" "attr cifs-utils debsums fio hfsprogs hwinfo lftp linux-generic-hwe-$DISTRIB_RELEASE linux-tools-generic mediainfo net-tools openssh-server ppa-purge pv s-nail screen syslinux-utils tlp tlp-rdw traceroute trickle vim whois xserver-xorg-hwe-$DISTRIB_RELEASE" N
sudo dmidecode -t system | grep -i ThinkPad &>/dev/null && apt_install_packages "ThinkPad power management" "acpi-call-dkms tp-smapi-dkms" N
apt_install_packages "performance monitoring" "atop iotop nethogs powertop sysstat" N
apt_install_packages "desktop essentials" "abcde autokey-gtk autorandr beets blueman bsd-mailx- caffeine code copyq dconf-editor eyed3 filezilla firefox fonts-symbola fonts-twemoji-svginot galculator gconf-editor geany ghostwriter gimp git-cola google-chrome-stable handbrake-cli handbrake-gtk indicator-multiload inkscape keepassxc lame libdvd-pkg! libreoffice meld mkvtoolnix mkvtoolnix-gui owncloud-client qpdfview remmina scribus seahorse speedcrunch sublime-text synaptic synergy thunderbird tilda tilix typora usb-creator-gtk vlc x11vnc"
apt_install_packages "PDF tools" "ghostscript pandoc texlive texlive-luatex"
apt_install_packages "photography" "geeqie rapid-photo-downloader"
apt_install_packages "development" 'libapache2-mod-php*- '"build-essential git nodejs php php-bcmath php-cli php-curl php-dev php-fpm php-gd php-gettext php-imagick php-imap php-json php-mbstring php-mcrypt? php-mysql php-pear php-soap php-xdebug php-xml php-xmlrpc python python-dateutil python-dev python-mysqldb python-requests ruby yarn"
apt_install_packages "development services" 'libapache2-mod-php*- '"apache2 libapache2-mod-fastcgi? libapache2-mod-fcgid? mariadb-server mongodb-org"
apt_package_available powershell && apt_install_packages "PowerShell" "powershell" || apt_install_packages "PowerShell" "powershell-preview"
apt_install_packages "VirtualBox" "virtualbox-6.0"
apt_install_packages "Docker CE" "docker-ce docker-ce-cli containerd.io"

# http://www.makemkv.com/forum2/viewtopic.php?f=3&t=224
apt_install_packages "MakeMKV dependencies" "libavcodec-dev libc6-dev libexpat1-dev libgl1-mesa-dev libqt4-dev libssl-dev pkg-config zlib1g-dev"

apt_install_deb "https://code-industry.net/public/master-pdf-editor-5.4.30-qt5.amd64.deb"
apt_install_deb "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" Y
#apt_install_deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" Y
apt_install_deb "https://github.com/KryDos/todoist-linux/releases/download/1.17/Todoist_1.17.0_amd64.deb"
apt_install_deb "https://github.com/careteditor/releases-beta/releases/download/4.0.0-rc23/caret-beta.deb"
apt_install_deb "https://go.skype.com/skypeforlinux-64.deb" Y
apt_install_deb "https://release.gitkraken.com/linux/gitkraken-amd64.deb" Y

apt_remove_packages apport deja-dup

if [ "$IS_ELEMENTARY_OS" -eq "1" -a "$(lsb_release -sc)" = "juno" ]; then

    apt_package_installed "wingpanel-indicator-ayatana" || get_confirmation "Install workaround for removal of system tray indicators?" && {

        # because too many apps don't play by the rules (see: https://www.reddit.com/r/elementaryos/comments/aghyiq/system_tray/)
        mkdir -p "$HOME/.config/autostart"
        cp -f "/etc/xdg/autostart/indicator-application.desktop" "$HOME/.config/autostart/"
        sed -i 's/^OnlyShowIn.*/OnlyShowIn=Unity;GNOME;Pantheon;/' "$HOME/.config/autostart/indicator-application.desktop"

        apt_install_deb "http://ppa.launchpad.net/elementary-os/stable/ubuntu/pool/main/w/wingpanel-indicator-ayatana/wingpanel-indicator-ayatana_2.0.3+r27+pkg17~ubuntu0.4.1.1_amd64.deb"

    }

    SLEEP_INACTIVE_AC_TIMEOUT="$(sudo -u lightdm -H dbus-launch gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 2>/dev/null)"
    SLEEP_INACTIVE_AC_TYPE="$(sudo -u lightdm -H dbus-launch gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 2>/dev/null)"

    [ "$SLEEP_INACTIVE_AC_TIMEOUT" = "0" -a "$SLEEP_INACTIVE_AC_TYPE" = "'nothing'" ] || get_confirmation "Prevent elementary OS from sleeping when locked?" && {

        sudo -u lightdm -H dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0 &>/dev/null &&
            sudo -u lightdm -H dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing &>/dev/null ||
            console_message "Unable to apply power settings for ${BOLD}lightdm${RESET} user:" "sleep-inactive-ac-timeout sleep-inactive-ac-type" $BOLD $RED >&2

    }

fi

SNAPS_INSTALL=()

if command -v snap &>/dev/null; then

    console_message "Installing all available snap updates..." "" $GREEN
    sudo snap refresh

    SNAPS_INSTALLED=($(sudo snap list 2>/dev/null))

    for s in caprine slack spotify teams-for-linux twist; do

        array_search "$s" SNAPS_INSTALLED >/dev/null || SNAPS_INSTALL+=("$s")

    done

    if [ "${#SNAPS_INSTALL[@]}" -gt "0" ]; then

        console_message "Missing $(single_or_plural ${#SNAPS_INSTALL[@]} snap snaps):" "${SNAPS_INSTALL[*]}" $BOLD $MAGENTA

        if ! get_confirmation "Add the $(single_or_plural ${#SNAPS_INSTALL[@]} snap snaps) listed above?"; then

            SNAPS_INSTALL=()

        fi

    fi

fi

apt_upgrade_all
apt_process_queue

# critical post-apt tasks

if apt_package_just_installed "libdvd-pkg"; then

    sudo debconf-set-selections <<EOF
libdvd-pkg libdvd-pkg/build boolean true
libdvd-pkg libdvd-pkg/first-install note
libdvd-pkg libdvd-pkg/post-invoke_hook-install boolean true
libdvd-pkg libdvd-pkg/post-invoke_hook-remove boolean false
libdvd-pkg libdvd-pkg/upgrade note
EOF

    sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure libdvd-pkg

fi

# non-apt installations

for s in "${SNAPS_INSTALL[@]}"; do

    # tolerate errors because snap can be temperamental
    sudo snap install --classic "$s" || true

done

# final tasks

if apt_package_installed "cups-browsed"; then

    # prevent AirPrint printers being added automatically
    sudo systemctl stop cups-browsed &>/dev/null && sudo systemctl disable cups-browsed &>/dev/null || die "Error disabling cups-browsed service"

fi

if apt_package_installed "virtualbox-6.0"; then

    sudo adduser "$USER" vboxusers &>/dev/null || die "Error adding $USER to vboxusers group"

fi

if apt_package_installed "docker-ce"; then

    sudo groupadd -f docker &>/dev/null && sudo adduser "$USER" docker &>/dev/null || die "Error adding $USER to docker group"

fi

ALL_PACKAGES=($(printf '%s\n' "${APT_INSTALLED[@]}" | sort | uniq))
console_message "${#ALL_PACKAGES[@]} installed $(single_or_plural ${#ALL_PACKAGES[@]} "package is" "packages are") managed by $(basename "$0"):" "" $BLUE
COLUMNS="$(tput cols)"
apt_pretty_packages "$(printf '%s\n' "${ALL_PACKAGES[@]}" | column -c "$COLUMNS")"
