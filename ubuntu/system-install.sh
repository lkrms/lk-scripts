#!/bin/bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-apt
. "$SCRIPT_DIR/../bash/common-apt"

assert_is_ubuntu
assert_not_server
assert_not_root

offer_sudo_password_bypass

# install prequisites and packages that may be needed to bootstrap others
apt_force_install_packages "apt-transport-https aptitude debconf-utils distro-info dmidecode lsb-core snapd software-properties-common trash-cli whiptail"

# ensure all of Ubuntu's repositories are available (including "backports" and "proposed" archives)
apt_enable_ubuntu_repository main "updates backports proposed"
apt_enable_ubuntu_repository restricted "updates backports proposed"
apt_enable_ubuntu_repository universe "updates backports proposed"
apt_enable_ubuntu_repository multiverse "updates backports proposed"
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
apt_register_ppa "heyarje/makemkv-beta" "makemkv-*"
apt_register_ppa "hluk/copyq" "copyq"
apt_register_ppa "inkscape.dev/stable" "inkscape"
apt_register_ppa "libreoffice/libreoffice-6-1" "libreoffice*" N N
apt_register_ppa "linrunner/tlp" "tlp tlp-rdw"
apt_register_ppa "phoerious/keepassxc" "keepassxc"
apt_register_ppa "scribus/ppa" "scribus*"
apt_register_ppa "stebbins/handbrake-releases" "handbrake-*"
apt_register_ppa "wereturtle/ppa" "ghostwriter"

# ditto for non-PPA repositories
apt_register_repository dbeaver "https://dbeaver.io/debs/dbeaver.gpg.key" "deb https://dbeaver.io/debs/dbeaver-ce /" "origin dbeaver.io" "dbeaver-ce"
apt_register_repository docker "https://download.docker.com/linux/ubuntu/gpg" "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable" "origin download.docker.com" "docker-ce* containerd.io"
apt_register_repository google-chrome "https://dl.google.com/linux/linux_signing_key.pub" "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" "origin dl.google.com" "google-chrome-*"
apt_register_repository microsoft "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/ubuntu/$DISTRIB_RELEASE/prod $DISTRIB_CODENAME main" "release o=microsoft-ubuntu-bionic-prod bionic,l=microsoft-ubuntu-bionic-prod bionic" "powershell*" Y
apt_register_repository mkvtoolnix "https://mkvtoolnix.download/gpg-pub-moritzbunkus.txt" "deb https://mkvtoolnix.download/ubuntu/ $DISTRIB_CODENAME main" "origin mkvtoolnix.download" "mkvtoolnix*"
apt_register_repository mongodb-org-4.0 "https://www.mongodb.org/static/pgp/server-4.0.asc" "deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" "origin repo.mongodb.org" "mongodb-org*"
apt_register_repository nodesource "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" "deb https://deb.nodesource.com/node_8.x $DISTRIB_CODENAME main" "origin deb.nodesource.com" "nodejs"
apt_register_repository owncloud-client "https://download.opensuse.org/repositories/isv:ownCloud:desktop/Ubuntu_$DISTRIB_RELEASE/Release.key" "deb http://download.opensuse.org/repositories/isv:/ownCloud:/desktop/Ubuntu_$DISTRIB_RELEASE/ /" "release l=isv:ownCloud:desktop" "owncloud-client" N N
apt_register_repository skype-stable "https://repo.skype.com/data/SKYPE-GPG-KEY" "deb [arch=amd64] https://repo.skype.com/deb stable main" "origin repo.skype.com" "skypeforlinux"
apt_register_repository sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "origin download.sublimetext.com" "sublime-*"
apt_register_repository typora "https://typora.io/linux/public-key.asc" "deb https://typora.io/linux ./" "origin typora.io" "typora"
apt_register_repository virtualbox "https://www.virtualbox.org/download/oracle_vbox_2016.asc" "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $DISTRIB_CODENAME contrib" "origin download.virtualbox.org" "virtualbox-*"
apt_register_repository vscode "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" "release o=vscode stable,l=vscode stable" "code code-*"
apt_register_repository yarn "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "origin dl.yarnpkg.com" "yarn"

apt_install_packages "essential utilities" "attr cifs-utils debsums fio hfsprogs hwinfo lftp linux-generic-hwe-$DISTRIB_RELEASE linux-tools-generic mediainfo net-tools openssh-server ppa-purge pv s-nail screen syslinux-utils tlp tlp-rdw traceroute trickle vim whois xserver-xorg-hwe-$DISTRIB_RELEASE" N

if sudo dmidecode -t system | grep -i ThinkPad >/dev/null 2>&1; then

    apt_install_packages "ThinkPad power management" "acpi-call-dkms tp-smapi-dkms" N

fi

apt_install_packages "performance monitoring" "atop iotop nethogs powertop sysstat" N
apt_install_packages "desktop essentials" "abcde beets blueman bsd-mailx- caffeine code copyq dconf-editor eyed3 filezilla firefox flameshot fonts-symbola galculator gconf-editor geany ghostwriter gimp git-cola gnome-color-manager google-chrome-stable gparted guake handbrake-cli handbrake-gtk indicator-multiload inkscape keepassxc lame libdvd-pkg! libreoffice makemkv-bin makemkv-oss meld mkvtoolnix mkvtoolnix-gui owncloud-client qpdfview remmina scribus seahorse shellcheck skypeforlinux speedcrunch sublime-text synaptic synergy thunderbird tilix typora usb-creator-gtk vlc x11vnc xbindkeys xdotool youtube-dl"
apt_install_packages "PDF tools" "ghostscript pandoc texlive texlive-luatex"
apt_install_packages "photography" "geeqie rapid-photo-downloader"
apt_install_packages "development" 'libapache2-mod-php*- '"build-essential cmake dbeaver-ce git nodejs php php-bcmath php-cli php-curl php-dev php-fpm php-gd php-gettext php-imagick php-imap php-json php-mbstring php-mcrypt? php-mysql php-pear php-soap php-xdebug php-xml php-xmlrpc python python-dateutil python-dev python-mysqldb python-pip python-requests python3 python3-dateutil python3-dev python3-mysqldb python3-pip python3-requests ruby yarn"
apt_install_packages "development services" 'libapache2-mod-php*- '"apache2 libapache2-mod-fastcgi? libapache2-mod-fcgid? mariadb-server mongodb-org"

if apt_package_available powershell; then

    apt_install_packages "PowerShell" "powershell"
    apt_remove_packages powershell-preview

else

    apt_install_packages "PowerShell" "powershell-preview"

fi

apt_install_packages "VirtualBox" "virtualbox-6.0"
apt_install_packages "Docker CE" "docker-ce docker-ce-cli containerd.io"

apt_install_deb "https://binaries.symless.com/synergy/v1-core-standard/v1.10.2-stable-8c010140/synergy_1.10.2.stable_b10%2B8c010140_ubuntu18_amd64.deb"
apt_install_deb "https://code-industry.net/public/master-pdf-editor-5.4.30-qt5.amd64.deb"
apt_install_deb "https://displaycal.net/download/xUbuntu_${DISTRIB_RELEASE}/amd64/DisplayCAL.deb"
apt_install_deb "https://github.com/autokey/autokey/releases/download/v0.95.7/autokey-common_0.95.7-0_all.deb"
apt_install_deb "https://github.com/autokey/autokey/releases/download/v0.95.7/autokey-gtk_0.95.7-0_all.deb"
apt_install_deb "https://github.com/careteditor/releases-beta/releases/download/4.0.0-rc23/caret-beta.deb"
apt_install_deb "https://github.com/IsmaelMartinez/teams-for-linux/releases/download/v0.3.0/teams-for-linux_0.3.0_amd64.deb"
apt_install_deb "https://github.com/KryDos/todoist-linux/releases/download/1.17/Todoist_1.17.0_amd64.deb"
apt_install_deb "https://release.gitkraken.com/linux/gitkraken-amd64.deb"
apt_install_deb "https://www.rescuetime.com/installers/rescuetime_current_amd64.deb"

apt_remove_packages apport deja-dup fonts-twemoji-svginot

if [ "$IS_ELEMENTARY_OS" -eq "1" ] && [ "$(lsb_release -sc)" = "juno" ]; then

    apt_install_packages "elementary OS extras" "com.github.cassidyjames.ideogram gnome-tweaks libgtk-3-dev"

    if apt_package_installed "wingpanel-indicator-ayatana" || get_confirmation "Install workaround for removal of system tray indicators?" Y Y; then

        # because too many apps don't play by the rules (see: https://www.reddit.com/r/elementaryos/comments/aghyiq/system_tray/)
        mkdir -p "$HOME/.config/autostart"
        cp -f "/etc/xdg/autostart/indicator-application.desktop" "$HOME/.config/autostart/"
        sed -i 's/^OnlyShowIn.*/OnlyShowIn=Unity;GNOME;Pantheon;/' "$HOME/.config/autostart/indicator-application.desktop"

        apt_install_deb "http://ppa.launchpad.net/elementary-os/stable/ubuntu/pool/main/w/wingpanel-indicator-ayatana/wingpanel-indicator-ayatana_2.0.3+r27+pkg17~ubuntu0.4.1.1_amd64.deb"

        if [ -e "$HOME/.themes/elementary/gtk-3.0/gtk.css" ]; then

            trash-put "$HOME/.themes/elementary/gtk-3.0/gtk.css"

        fi

        mkdir -p "$HOME/.themes/elementary/gtk-3.0"

        cat <<EOF >"$HOME/.themes/elementary/gtk-3.0/gtk.css"
@import url("/usr/share/themes/elementary/gtk-3.0/gtk.css");

.composited-indicator.horizontal {
    padding: 0;
}

.composited-indicator.horizontal .composited-indicator {
    padding: 3px;
}
EOF

    fi

    # use a subshell to protect existing D-Bus environment variables
    (
        set -euo pipefail

        LIGHTDM_HOME=~lightdm

        SUDO_EXTRA=(-u lightdm -H "DISPLAY=" "XAUTHORITY=\"$LIGHTDM_HOME/.Xauthority\"")

        # shellcheck disable=SC1090
        . <(sudo "${SUDO_EXTRA[@]}" dbus-launch --sh-syntax)

        SLEEP_INACTIVE_AC_TIMEOUT="$(sudo "${SUDO_EXTRA[@]}" gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 2>/dev/null)"
        SLEEP_INACTIVE_AC_TYPE="$(sudo "${SUDO_EXTRA[@]}" gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 2>/dev/null)"

        if [ "$SLEEP_INACTIVE_AC_TIMEOUT" = "0" ] && [ "$SLEEP_INACTIVE_AC_TYPE" = "'nothing'" ] || get_confirmation "Prevent elementary OS from sleeping when locked?" Y Y; then

            sudo "${SUDO_EXTRA[@]}" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0 >/dev/null 2>&1 &&
                sudo "${SUDO_EXTRA[@]}" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing >/dev/null 2>&1 ||
                console_message "Unable to apply power settings for ${BOLD}lightdm${RESET} user:" "sleep-inactive-ac-timeout sleep-inactive-ac-type" "$BOLD" "$RED" >&2

        fi

        sudo "${SUDO_EXTRA[@]}" kill "$DBUS_SESSION_BUS_PID"
    )

fi

# shellcheck disable=SC2034
SNAPS_INSTALLED=($(sudo snap list 2>/dev/null))
SNAPS_INSTALL=()

for s in caprine slack spotify twist; do

    array_search "$s" SNAPS_INSTALLED >/dev/null || SNAPS_INSTALL+=("$s")

done

if [ "${#SNAPS_INSTALL[@]}" -gt "0" ]; then

    console_message "Missing $(single_or_plural ${#SNAPS_INSTALL[@]} snap snaps):" "${SNAPS_INSTALL[*]}" "$BOLD" "$MAGENTA"

    if ! get_confirmation "Add the $(single_or_plural ${#SNAPS_INSTALL[@]} snap snaps) listed above?" Y Y; then

        SNAPS_INSTALL=()

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

console_message "Installing all available snap updates..." "" "$GREEN"
sudo snap refresh

for s in "${SNAPS_INSTALL[@]}"; do

    # tolerate errors because snap can be temperamental
    sudo snap install --classic "$s" || true

done

# final tasks

apply_system_config

if apt_package_installed "libgtk-3-dev"; then

    gsettings set org.gtk.Settings.Debug enable-inspector-keybinding true

fi

if apt_package_installed "cups-browsed"; then

    # prevent AirPrint printers being added automatically
    sudo systemctl stop cups-browsed >/dev/null 2>&1 && sudo systemctl disable cups-browsed >/dev/null 2>&1 || die "Error disabling cups-browsed service"

fi

if apt_package_installed "virtualbox-[0-9.]+"; then

    sudo adduser "$USER" vboxusers >/dev/null 2>&1 || die "Error adding $USER to vboxusers group"

fi

if apt_package_installed "docker-ce"; then

    sudo groupadd -f docker >/dev/null 2>&1 && sudo adduser "$USER" docker >/dev/null 2>&1 || die "Error adding $USER to docker group"

fi

ALL_PACKAGES=($(printf '%s\n' "${APT_INSTALLED[@]}" | sort | uniq))
console_message "${#ALL_PACKAGES[@]} installed $(single_or_plural ${#ALL_PACKAGES[@]} "package is" "packages are") managed by $(basename "$0"):" "" "$BLUE"
COLUMNS="$(tput cols)"
apt_pretty_packages "$(printf '%s\n' "${ALL_PACKAGES[@]}" | column -c "$COLUMNS")"
