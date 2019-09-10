#!/bin/bash
# shellcheck disable=SC1090,SC2206,SC2207

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v realpath >/dev/null 2>&1; then SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"; fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"

# shellcheck source=../bash/common
. "$SCRIPT_DIR/../bash/common"

# shellcheck source=../bash/common-apt
. "$SCRIPT_DIR/../bash/common-apt"

# shellcheck source=../bash/common-dev
. "$SCRIPT_DIR/../bash/common-dev"

assert_is_ubuntu
assert_has_gui
assert_not_root

APT_GUI_PACKAGES="\
audacity
autokey-common
autokey-gtk
awf
blueman
caffeine
caprine
catfish
code
com.github.cassidyjames.ideogram
copyq
dbeaver-ce
dconf-editor
deepin-screenshot
displaycal
firefox
galculator
gconf-editor
geany
geeqie
ghostwriter
gimp
git-cola
gnome-color-manager
gnome-session-canberra
gnome-tweaks
google-chrome-stable
gparted
guake
handbrake-gtk
indicator-multiload
inkscape
intel-gpu-tools
keepassxc
libcanberra-gtk-module
libcanberra-gtk3-module
libgtk-3-dev
libreoffice
makemkv-bin
makemkv-oss
master-pdf-editor
meld
mkvtoolnix-gui
owncloud-client
plank
qpdfview
quicktile
rapid-photo-downloader
recoll
remmina
rescuetime
scribus
seahorse
skypeforlinux
slack-desktop
speedcrunch
spotify-client
stretchly
sublime-merge
sublime-text
synaptic
synergy
t1-xfree86-nonfree
teams-for-linux
thunderbird
tilix
transmission
trimage
twist
usb-creator-gtk
vlc
wingpanel-indicator-ayatana
x-tile
x11vnc
xautomation
xclip
xdotool
xfce4-clipman
xfonts-100dpi
xfonts-75dpi
xscreensaver
xscreensaver-data
xscreensaver-data-extra
xscreensaver-gl
xscreensaver-gl-extra
xscreensaver-screensaver-bsod
xscreensaver-screensaver-webcollage
"

offer_sudo_password_bypass

for FILE in 10-help-text 50-motd-news 80-esm 80-livepatch 90-updates-available 91-release-upgrade 95-hwe-eol; do

    if [ -x "/etc/update-motd.d/$FILE" ]; then

        sudo chmod a-x "/etc/update-motd.d/$FILE"

    fi

done

apt_mark_cache_clean

# install prequisites and packages that may be needed to bootstrap others
apt_force_install_packages "apt-transport-https aptitude debconf-utils distro-info dmidecode lsb-core snapd software-properties-common trash-cli whiptail"

# ensure all of Ubuntu's repositories are available (including "backports" and "proposed" archives)
apt_enable_ubuntu_repository main "updates backports proposed"
apt_enable_ubuntu_repository restricted "updates backports proposed"
apt_enable_ubuntu_repository universe "updates backports proposed"
apt_enable_ubuntu_repository multiverse "updates backports proposed"

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
apt_register_ppa "flexiondotorg/awf" "awf"
apt_register_ppa "giuspen/ppa" "x-tile"
apt_register_ppa "hda-me/xscreensaver" "xscreensaver*"
apt_register_ppa "heyarje/makemkv-beta" "makemkv-*"
apt_register_ppa "hluk/copyq" "copyq"
apt_register_ppa "inkscape.dev/stable" "inkscape"
apt_register_ppa "libreoffice/ppa" "libreoffice*" N N
apt_register_ppa "linrunner/tlp" "tlp tlp-rdw"
apt_register_ppa "phoerious/keepassxc" "keepassxc"
apt_register_ppa "recoll-backports/recoll-1.15-on" "recoll *-recoll"
apt_register_ppa "scribus/ppa" "scribus*"
apt_register_ppa "stebbins/handbrake-releases" "handbrake-*"
apt_register_ppa "ubuntuhandbook1/audacity" "audacity*"
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
apt_register_repository spotify "931FF8E79F0876134EDDBDCCA87FF9DF48BF1C90 2EBF997C15BDA244B6EBF5D84773BD5E130D1D45" "deb http://repository.spotify.com stable non-free" "origin repository.spotify.com" "spotify-client"
apt_register_repository sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "origin download.sublimetext.com" "sublime-*"
apt_register_repository typora "https://typora.io/linux/public-key.asc" "deb https://typora.io/linux ./" "origin typora.io" "typora"
apt_register_repository virtualbox "https://www.virtualbox.org/download/oracle_vbox_2016.asc" "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $DISTRIB_CODENAME contrib" "origin download.virtualbox.org" "virtualbox-*"
apt_register_repository vscode "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" "release o=vscode stable,l=vscode stable" "code code-*"
apt_register_repository yarn "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "origin dl.yarnpkg.com" "yarn"

apt_install_packages "essential utilities" "\
 attr\
 cifs-utils\
 curl\
 debsums\
 hfsprogs\
 hwinfo\
 ksh\
 lftp\
 libsecret-tools\
 linux-tools-generic\
 mediainfo\
 msmtp\
 net-tools\
 ntp\
 ntpdate\
 openssh-server\
 ppa-purge\
 pv\
 s-nail\
 screen\
 syslinux-utils\
 traceroute\
 vim\
 whois\
" N

if ! is_virtual; then

    apt_install_packages "power management" "\
 tlp\
 tlp-rdw\
" N

    if sudo dmidecode -t system | grep -i ThinkPad >/dev/null 2>&1; then

        apt_install_packages "ThinkPad power management" "acpi-call-dkms tp-smapi-dkms" N

    fi

fi

apt_install_packages "openconnect dependencies" "libxml2-dev pkg-config vpnc-scripts" N

apt_install_packages "QuickTile dependencies" "\
 python\
 python-gtk2\
 python-xlib\
 python-dbus\
 python-wnck?\
 python-setuptools\
" N

apt_install_packages "performance monitoring" "\
 atop\
 auditd\
 glances\
 intel-gpu-tools\
 iotop\
 lm-sensors\
 nethogs\
 powertop\
 sysstat\
" N

apt_install_packages "load testing" "\
 fio\
 trickle\
" N

apt_install_packages "desktop essentials" "\
 abcde\
 audacity\
 awf\
 beets\
 blueman\
 bsd-mailx-\
 caffeine\
 catfish\
 code\
 copyq\
 dconf-cli\
 dconf-editor\
 deepin-notifications-\
 deepin-screenshot\
 evtest\
 eyed3\
 firefox\
 fonts-symbola\
 galculator\
 gconf-editor\
 geany\
 ghostwriter\
 gimp\
 git-cola\
 gnome-color-manager\
 google-chrome-stable\
 gparted\
 guake\
 handbrake-cli\
 handbrake-gtk\
 indicator-multiload\
 inkscape\
 keepassxc\
 lame\
 libdvd-pkg!\
 libreoffice\
 makemkv-bin\
 makemkv-oss\
 meld\
 mkvtoolnix-gui\
 mkvtoolnix\
 owncloud-client\
 qpdfview\
 recoll\
 remmina\
 samba\
 scribus\
 seahorse\
 skypeforlinux\
 speedcrunch\
 spotify-client\
 sublime-text\
 sxhkd\
 synaptic\
 t1-xfree86-nonfree\
 thunderbird\
 tilix\
 transmission\
 ttf-xfree86-nonfree\
 typora\
 usb-creator-gtk\
 vlc\
 x-tile\
 x11vnc\
 xautomation\
 xclip\
 xdotool\
 xfonts-100dpi\
 xfonts-75dpi\
 youtube-dl\
"

apt_install_packages "PDF tools" "\
 ghostscript\
 mupdf\
 mupdf-tools\
 pandoc\
 texlive\
 texlive-luatex\
"

apt_install_packages "photography" "\
 geeqie\
 rapid-photo-downloader\
 trimage\
"

apt_install_packages "development" "\
 build-essential\
 cmake\
 dbeaver-ce\
 git\
 libapache2-mod-php*-\
 nodejs\
 php\
 php-bcmath\
 php-cli\
 php-curl\
 php-dev\
 php-fpm\
 php-gd\
 php-gettext\
 php-imagick\
 php-imap\
 php-json\
 php-mbstring\
 php-mcrypt?\
 php-memcache\
 php-memcached\
 php-mysql\
 php-pear\
 php-soap\
 php-xdebug\
 php-xml\
 php-xmlrpc\
 python\
 python-dateutil\
 python-dev\
 python-mysqldb\
 python-pip\
 python-requests\
 python3\
 python3-dateutil\
 python3-dev\
 python3-mysqldb\
 python3-pip\
 python3-requests\
 ruby\
 shellcheck\
 sublime-merge\
 yarn\
"

apt_install_packages "development services" "\
 apache2\
 libapache2-mod-php*-\
 mariadb-server\
 mongodb-org\
"

if apt_package_available powershell; then

    apt_install_packages "PowerShell" "powershell"
    apt_remove_packages powershell-preview

else

    apt_install_packages "PowerShell" "powershell-preview"

fi

apt_install_packages "VirtualBox" "virtualbox-6.0"
apt_install_packages "Docker CE" "docker-ce docker-ce-cli containerd.io"

case "${XDG_CURRENT_DESKTOP:-}" in

XFCE)

    apt_install_packages "XFCE extras" "gnome-session-canberra libcanberra-gtk-module libcanberra-gtk3-module plank sox ubuntu-sounds xfce4-clipman xfdashboard xscreensaver xscreensaver-data xscreensaver-data-extra xscreensaver-gl xscreensaver-gl-extra xscreensaver-screensaver-bsod xscreensaver-screensaver-webcollage"
    apt_remove_packages "light-locker"

    ;;

Pantheon)

    apt_install_packages "elementary OS extras" "com.github.cassidyjames.ideogram gnome-tweaks libgtk-3-dev"

    if ! has_argument "--skip-debs" && { apt_package_installed "wingpanel-indicator-ayatana" || get_confirmation "Restore elementary OS system tray indicators?" Y Y; }; then

        # because too many apps don't play by the rules (see: https://www.reddit.com/r/elementaryos/comments/aghyiq/system_tray/)
        mkdir -p "$HOME/.config/autostart"
        cp -f "/etc/xdg/autostart/indicator-application.desktop" "$HOME/.config/autostart/"
        sed "${SED_IN_PLACE_ARGS[@]}" 's/^OnlyShowIn.*/OnlyShowIn=Unity;GNOME;Pantheon;/' "$HOME/.config/autostart/indicator-application.desktop"

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
        . "$SUBSHELL_SCRIPT_PATH" || exit

        SUDO_EXTRA=(-nu lightdm -H env -i)

        DBUS_LAUNCH_CODE="$(sudo "${SUDO_EXTRA[@]}" dbus-launch --sh-syntax)"

        # shellcheck disable=SC1091
        . /dev/stdin <<<"$DBUS_LAUNCH_CODE"

        SUDO_EXTRA+=("DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS")

        SLEEP_INACTIVE_AC_TIMEOUT="$(sudo "${SUDO_EXTRA[@]}" gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout)"
        SLEEP_INACTIVE_AC_TYPE="$(sudo "${SUDO_EXTRA[@]}" gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)"

        if [ "$SLEEP_INACTIVE_AC_TIMEOUT" = "0" ] && [ "$SLEEP_INACTIVE_AC_TYPE" = "'nothing'" ] || get_confirmation "Prevent elementary OS from sleeping when locked and using AC power?" Y Y; then

            sudo "${SUDO_EXTRA[@]}" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0 &&
                sudo "${SUDO_EXTRA[@]}" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing ||
                console_message "Unable to apply power settings for ${BOLD}lightdm${RESET} user:" "sleep-inactive-ac-timeout sleep-inactive-ac-type" "$BOLD" "$RED" >&2

        fi

        sudo "${SUDO_EXTRA[@]}" kill "$DBUS_SESSION_BUS_PID"
    )

    ;;

esac

if ! has_argument "--skip-debs"; then

    apt_install_deb "https://binaries.symless.com/synergy/v1-core-standard/v1.10.3-stable-ca35737a/synergy_1.10.3.stable_b24%2Bca35737a_ubuntu18_amd64.deb"
    apt_install_deb "https://displaycal.net/download/xUbuntu_${DISTRIB_RELEASE}/amd64/DisplayCAL.deb"
    apt_install_deb "https://www.rescuetime.com/installers/rescuetime_current_amd64.deb"

    DEB_URLS=()
    IFS=$'\n'

    # AutoKey
    DEB_URLS+=($(
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit
        get_urls_from_url "https://api.github.com/repos/autokey/autokey/releases/latest" 'autokey-(common|gtk).*\.deb$' | head -n2
    ))

    # Caprine
    DEB_URLS+=("$(
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit
        get_urls_from_url "https://api.github.com/repos/sindresorhus/caprine/releases/latest" '_amd64\.deb$' | head -n1
    )")

    # Caret Beta
    DEB_URLS+=("$(
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit
        get_urls_from_url "https://api.github.com/repos/careteditor/releases-beta/releases/latest" '\.deb$' | head -n1
    )")

    # Master PDF Editor
    DEB_URLS+=("$(
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit
        get_urls_from_url "https://code-industry.net/free-pdf-editor/" '.*-qt5\.amd64\.deb$' | head -n1
    )")

    # Slack
    DEB_URLS+=("$(
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit
        get_urls_from_url "https://slack.com/intl/en-au/downloads/instructions/ubuntu" '.*\.deb$' | head -n1
    )")

    # stretchly
    DEB_URLS+=("$(
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit
        get_urls_from_url "https://api.github.com/repos/hovancik/stretchly/releases/latest" '_amd64\.deb$' | head -n1
    )")

    # Teams for Linux
    DEB_URLS+=("$(
        # shellcheck source=../bash/common-subshell
        . "$SUBSHELL_SCRIPT_PATH" || exit
        get_urls_from_url "https://api.github.com/repos/IsmaelMartinez/teams-for-linux/releases/latest" '_amd64\.deb$' | head -n1
    )")

    unset IFS

    for DEB_URL in "${DEB_URLS[@]}"; do

        apt_install_deb "$DEB_URL"
        console_message "Queued for download:" "${NO_WRAP}${DEB_URL}${WRAP}" "$BOLD" "$YELLOW"

    done

fi

apt_remove_packages apport deja-dup filezilla fonts-twemoji-svginot libapache2-mod-fastcgi libapache2-mod-fcgid libxss-dev

dev_install_packages Y APT_INSTALLED

# shellcheck disable=SC2034
SNAPS_INSTALLED=($(sudo snap list 2>/dev/null))
SNAPS_INSTALL=()

for s in twist; do

    array_search "$s" SNAPS_INSTALLED >/dev/null && APT_INSTALLED+=("$s") || SNAPS_INSTALL+=("$s")

done

if [ "${#SNAPS_INSTALL[@]}" -gt "0" ]; then

    console_message "Missing $(single_or_plural ${#SNAPS_INSTALL[@]} snap snaps):" "${SNAPS_INSTALL[*]}" "$BOLD" "$MAGENTA"

    if ! get_confirmation "Add the $(single_or_plural ${#SNAPS_INSTALL[@]} snap snaps) listed above?" Y Y; then

        SNAPS_INSTALL=()

    fi

fi

# we're about to install ntp
if command_exists timedatectl; then

    sudo timedatectl set-ntp no

fi

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

if apt_package_installed "samba"; then

    console_message "Configuring Samba..." "" "$CYAN"

    if apt_package_just_installed "samba"; then

        "$ROOT_DIR/linux/dev-samba-configure.sh" --reset

    else

        "$ROOT_DIR/linux/dev-samba-configure.sh"

    fi

    sudo pdbedit -L | grep '^'"$USER"':' >/dev/null || {

        sudo smbpasswd -san "$USER" &&
            echoc "${BOLD}WARNING: Samba user $USER has been added with no password${RESET} (use smbpasswd to create one)" "$RED"

    }

fi

if apt_package_installed "ntp"; then

    console_message "Configuring NTP..." "" "$CYAN"

    sudo_function move_file_delete_link "/etc/ntp.conf"

    if [ -e "$CONFIG_DIR/ntp.conf" ]; then

        sudo ln -sv "$CONFIG_DIR/ntp.conf" "/etc/ntp.conf"

    else

        sudo ln -sv "$CONFIG_DIR/ntp-default.conf" "/etc/ntp.conf"

    fi

    if [ -f "/etc/apparmor.d/usr.sbin.ntpd" ] && ! [ -e "/etc/apparmor.d/disable/usr.sbin.ntpd" ]; then

        sudo ln -sv "../usr.sbin.ntpd" "/etc/apparmor.d/disable/usr.sbin.ntpd"

        sudo apparmor_parser -R "/etc/apparmor.d/usr.sbin.ntpd" 2>/dev/null || true

    fi

    sudo service ntp restart

fi

if apt_package_installed "apache2"; then

    console_message "Configuring Apache..." "" "$CYAN"

    dir_make_and_own /var/www/virtual

    mkdir -p /var/www/virtual/127.0.0.1

    # TODO: abstract this to a function like is_user_in_group
    groups | grep -Eq '(\s|^)(www-data)(\s|$)' || sudo adduser "$(id -un)" "www-data"
    groups "www-data" | grep -Eo '[^:]+$' | grep -Eq '(\s|^)'"$(id -gn)"'(\s|$)' || sudo adduser "www-data" "$(id -gn)"

    sudo_function move_file_delete_link "/etc/apache2/sites-available/000-virtual-linacreative.conf"

    if [ -e "$CONFIG_DIR/apache2-virtual.conf" ]; then

        sudo ln -sv "$CONFIG_DIR/apache2-virtual.conf" "/etc/apache2/sites-available/000-virtual-linacreative.conf"

    else

        sudo ln -sv "$CONFIG_DIR/apache2-virtual-default.conf" "/etc/apache2/sites-available/000-virtual-linacreative.conf"

    fi

    sudo rm -f /etc/apache2/sites-enabled/*.conf
    sudo ln -sv ../sites-available/000-virtual-linacreative.conf /etc/apache2/sites-enabled/000-virtual-linacreative.conf

    sudo a2enmod headers
    sudo a2enmod proxy
    sudo a2enmod proxy_fcgi
    sudo a2enmod rewrite
    sudo a2enmod vhost_alias

    sudo service apache2 restart

fi

if apt_package_installed "mariadb-server"; then

    console_message "Configuring MariaDB..." "" "$CYAN"

    sudo_function move_file_delete_link "/etc/mysql/mariadb.conf.d/60-linacreative.cnf"

    if [ -e "$CONFIG_DIR/mariadb.cnf" ]; then

        sudo ln -sv "$CONFIG_DIR/mariadb.cnf" "/etc/mysql/mariadb.conf.d/60-linacreative.cnf"

    else

        sudo ln -sv "$CONFIG_DIR/mariadb-default.cnf" "/etc/mysql/mariadb.conf.d/60-linacreative.cnf"

    fi

    # reload isn't enough
    sudo service mysql restart

fi

if ! apt_package_installed "python-wnck"; then

    apt_install_deb "http://old-releases.ubuntu.com/ubuntu/pool/main/g/gnome-python-desktop/python-wnck_2.32.0-0ubuntu6_amd64.deb"

    apt_process_queue

fi

# non-apt installations

DEV_JUST_INSTALLED=()
dev_process_queue DEV_JUST_INSTALLED

if [ "${#DEV_JUST_INSTALLED[@]}" -gt "0" ]; then

    APT_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")
    APT_JUST_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")

fi

if ! sudo -H pip list --format freeze 2>/dev/null | grep -E '^QuickTile==' >/dev/null; then

    sudo -H pip install "https://github.com/ssokolow/quicktile/archive/master.zip" && {
        APT_INSTALLED+=("quicktile")
        APT_JUST_INSTALLED+=("quicktile")
    }

else

    APT_INSTALLED+=("quicktile")

fi

if ! sudo -H pip3 list --format freeze 2>/dev/null | grep -E '^vpn-slice==' >/dev/null; then

    sudo -H pip3 install "https://github.com/dlenski/vpn-slice/archive/master.zip" && {
        APT_INSTALLED+=("vpn-slice")
        APT_JUST_INSTALLED+=("vpn-slice")
    }

else

    APT_INSTALLED+=("vpn-slice")

fi

for i in "${!SNAPS_INSTALL[@]}"; do

    # tolerate errors because snap can be temperamental
    sudo snap install "${SNAPS_INSTALL[$i]}" && {
        APT_INSTALLED+=("${SNAPS_INSTALL[$i]}")
        APT_JUST_INSTALLED+=("${SNAPS_INSTALL[$i]}")
    } || true

done

# final tasks

dev_apply_system_config

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

if apt_package_installed "libgtk-3-dev"; then

    gsettings set org.gtk.Settings.Debug enable-inspector-keybinding true

fi

# workaround for bugs introduced in libx11-6 2:1.6.4-3ubuntu0.2
HOLD_PACKAGES=(libx11-6 libx11-data libx11-dev libx11-doc libx11-xcb-dev libx11-xcb1)

for i in "${!HOLD_PACKAGES[@]}"; do

    if ! apt_package_installed "${HOLD_PACKAGES[$i]}"; then

        unset "HOLD_PACKAGES[$i]"

    fi

done

if [ "${#HOLD_PACKAGES[@]}" -gt "0" ] && dpkg-query -f '${Version}\n' -W "${HOLD_PACKAGES[@]}" | grep -Eq "$(sed_escape_search "2:1.6.4-3ubuntu0.2")"; then

    VERSIONED_HOLD_PACKAGES=()

    for p in "${HOLD_PACKAGES[@]}"; do

        VERSIONED_HOLD_PACKAGES+=("$p=2:1.6.4-3ubuntu0.1")

    done

    console_message "Downgrading from ${BOLD}2:1.6.4-3ubuntu0.2${RESET} to ${BOLD}2:1.6.4-3ubuntu0.1${RESET} and marking as held:" "${HOLD_PACKAGES[*]}" "$BOLD" "$RED"

    sudo apt-get "${APT_GET_OPTIONS[@]}" --allow-downgrades install "${VERSIONED_HOLD_PACKAGES[@]}"

    sudo apt-mark hold "${HOLD_PACKAGES[@]}"

fi

"$ROOT_DIR/bash/dev-system-update.sh"

apt_purge --no-y

ALL_PACKAGES=($(printf '%s\n' "${APT_INSTALLED[@]}" | grep -Eo '[^/]+$' | sort | uniq))
console_message "${#ALL_PACKAGES[@]} installed $(single_or_plural ${#ALL_PACKAGES[@]} "package is" "packages are") managed by $(basename "$0"):" "" "$BLUE"
COLUMNS="$(tput cols)" && apt_pretty_packages "$(printf '%s\n' "${ALL_PACKAGES[@]}" | column -c "$COLUMNS")" || apt_pretty_packages "${ALL_PACKAGES[*]}" Y

if apt_package_available "linux-generic-hwe-$DISTRIB_RELEASE" && apt_package_available "xserver-xorg-hwe-$DISTRIB_RELEASE" && ! apt_package_installed "linux-generic-hwe-$DISTRIB_RELEASE" && ! apt_package_installed "xserver-xorg-hwe-$DISTRIB_RELEASE"; then

    echo
    console_message "To use the Ubuntu LTS enablement stack, but only for X server, run:" "sudo apt-get install linux-generic-hwe-${DISTRIB_RELEASE}- xserver-xorg-hwe-$DISTRIB_RELEASE" "$BOLD" "$CYAN"

fi
