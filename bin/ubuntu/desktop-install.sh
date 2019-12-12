#!/bin/bash
# shellcheck disable=SC1090,SC2206,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"
. "$SCRIPT_DIR/../../bash/common-apt"
. "$SCRIPT_DIR/../../bash/common-dev"
. "$SCRIPT_DIR/../../bash/common-homebrew"

assert_is_ubuntu
assert_has_gui
assert_not_root

# allow this script to be changed while it's running
{
    offer_sudo_password_bypass

    disable_update_motd

    # apply all available preferences in $CONFIG_DIR/apt/preferences.d
    apt_apply_preferences

    safe_symlink "$CONFIG_DIR/apt.conf" "/etc/apt/apt.conf.d/90-linacreative" Y Y

    # get underway without an immediate index update
    apt_mark_cache_clean

    # ensure all of Ubuntu's repositories are available (including "backports" and "proposed" archives)
    apt_enable_ubuntu_repository main "updates backports proposed"
    apt_enable_ubuntu_repository restricted "updates backports proposed"
    apt_enable_ubuntu_repository universe "updates backports proposed"
    apt_enable_ubuntu_repository multiverse "updates backports proposed"

    # seed debconf database with answers
    sudo debconf-set-selections <<EOF
kdump-tools kdump-tools/use_kdump boolean true
kexec-tools kexec-tools/load_kexec boolean false
libc6 libraries/restart-without-asking boolean true
libpam0g libraries/restart-without-asking boolean true
EOF

    APT_PREREQ+=(
        ruby
        trash-cli
    )

    apt_check_prerequisites

    MEMORY_SIZE_MB=-1
    LOW_RAM=0

    if ! is_virtual; then

        MEMORY_SIZE_MB="$(get_memory_size)"

        [ "$MEMORY_SIZE_MB" -ge "8192" ] || {
            LOW_RAM=1
            console_message "Because this system has less than 8GB of RAM, some packages will not be offered" "" "$RED"
        }

    else

        console_message "Because this is a virtual machine, some packages will not be offered" "" "$RED"

    fi

    # register PPAs (note: this doesn't add them to the system straightaway; they are added on-demand if/when the relevant packages are actually installed)
    apt_register_ppa "hda-me/xscreensaver" "xscreensaver*"
    apt_register_ppa "heyarje/makemkv-beta" "makemkv-*"
    apt_register_ppa "hluk/copyq" "copyq"
    apt_register_ppa "inkscape.dev/stable" "inkscape"
    apt_register_ppa "libreoffice/ppa" "libreoffice*" N N
    apt_register_ppa "linrunner/tlp" "tlp tlp-rdw"
    apt_register_ppa "nextcloud-devs/client" "nextcloud-client"
    apt_register_ppa "phoerious/keepassxc" "keepassxc"
    apt_register_ppa "recoll-backports/recoll-1.15-on" "recoll *-recoll"
    apt_register_ppa "scribus/ppa" "scribus*"
    apt_register_ppa "stebbins/handbrake-releases" "handbrake-*"
    apt_register_ppa "ubuntuhandbook1/audacity" "audacity*"
    apt_register_ppa "wereturtle/ppa" "ghostwriter"

    # ditto for non-PPA repositories
    apt_register_repository dbeaver "https://dbeaver.io/debs/dbeaver.gpg.key" "deb https://dbeaver.io/debs/dbeaver-ce /" "origin dbeaver.io" "dbeaver-ce"
    apt_register_repository displaycal "https://download.opensuse.org/repositories/home:/fhoech/xUbuntu_18.04/Release.key" "deb https://download.opensuse.org/repositories/home:/fhoech/xUbuntu_$DISTRIB_RELEASE/ /" "release l=home:fhoech" "displaycal"
    apt_register_repository docker "https://download.docker.com/linux/ubuntu/gpg" "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable" "origin download.docker.com" "docker-ce* containerd.io"
    apt_register_repository google-chrome "https://dl.google.com/linux/linux_signing_key.pub" "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" "origin dl.google.com" "google-chrome-*"
    apt_register_repository microsoft "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/ubuntu/$DISTRIB_RELEASE/prod $DISTRIB_CODENAME main" "release o=microsoft-ubuntu-bionic-prod bionic,l=microsoft-ubuntu-bionic-prod bionic" "powershell*" Y
    apt_register_repository mkvtoolnix "https://mkvtoolnix.download/gpg-pub-moritzbunkus.txt" "deb https://mkvtoolnix.download/ubuntu/ $DISTRIB_CODENAME main" "origin mkvtoolnix.download" "mkvtoolnix*"
    apt_register_repository mongodb-org-4.0 "https://www.mongodb.org/static/pgp/server-4.0.asc" "deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" "origin repo.mongodb.org" "mongodb-org*"
    apt_register_repository nodesource "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" "deb https://deb.nodesource.com/node_8.x $DISTRIB_CODENAME main" "origin deb.nodesource.com" "nodejs"
    apt_register_repository signal "https://updates.signal.org/desktop/apt/keys.asc" "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" "origin updates.signal.org" "signal-desktop"
    apt_register_repository skype-stable "https://repo.skype.com/data/SKYPE-GPG-KEY" "deb [arch=amd64] https://repo.skype.com/deb stable main" "origin repo.skype.com" "skypeforlinux"
    apt_register_repository spotify "931FF8E79F0876134EDDBDCCA87FF9DF48BF1C90 2EBF997C15BDA244B6EBF5D84773BD5E130D1D45" "deb http://repository.spotify.com stable non-free" "origin repository.spotify.com" "spotify-client"
    apt_register_repository sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "origin download.sublimetext.com" "sublime-*"
    apt_register_repository teams "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/ms-teams stable main" "release o=ms-teams stable,l=ms-teams stable" "teams teams-*"
    apt_register_repository typora "https://typora.io/linux/public-key.asc" "deb https://typora.io/linux ./" "origin typora.io" "typora"
    apt_register_repository vscode "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" "release o=vscode stable,l=vscode stable" "code code-*"
    apt_register_repository yarn "https://dl.yarnpkg.com/debian/pubkey.gpg" "deb https://dl.yarnpkg.com/debian/ stable main" "origin dl.yarnpkg.com" "yarn"

    # otherwise pip, pip3, npm, composer packages will be skipped until next run
    apt_install_packages "development prerequisites" "nodejs php-cli python-pip python3-pip" Y N

    apt_check_essentials

    DESKTOP_PREREQ=(
        apparmor-utils
        stow
        xxd

        # OpenConnect (build) dependencies
        autoconf automake build-essential gettext libgnutls-dev? libgnutls28-dev? libproxy-dev libtool libxml2-dev pkg-config vpnc-scripts zlib1g-dev

        # xiccd (build) dependencies
        libcolord-dev
        libxrandr-dev
        libx11-dev

        # QuickTile dependencies
        python python-dbus python-gtk2 python-setuptools python-wnck? python-xlib

        # espanso dependencies
        libxdo3 libxtst6 xclip

    )

    apt_install_packages "application dependencies" "${DESKTOP_PREREQ[*]}" N

    DESKTOP_ESSENTIALS=(
        # basics
        copyq
        deepin-screenshot
        evolution
        firefox
        galculator
        geany
        ghostwriter
        gimp
        gnome-calendar
        google-chrome-stable
        inkscape
        keepassxc
        libreoffice
        #nextcloud-client
        qpdfview
        remmina
        scribus
        signal-desktop
        skypeforlinux
        speedcrunch
        spotify-client
        teams
        transmission
        transmission-cli
        typora

        # PDF
        ghostscript
        mupdf
        mupdf-tools
        pandoc
        pstoedit
        texlive
        texlive-luatex

        # search
        catfish
        gssp-recoll
        recoll

        # photography
        geeqie
        rapid-photo-downloader
        trimage

        # multimedia
        abcde
        audacity
        beets
        eyed3
        ffmpeg
        handbrake-cli
        handbrake-gtk
        lame
        libdvd-pkg!
        makemkv-bin
        makemkv-oss
        mkvtoolnix
        mkvtoolnix-gui
        mpv
        rtmpdump
        vlc

        # system
        argyll
        dconf-cli
        dconf-editor
        displaycal
        gconf-editor
        glmark2
        gparted
        guake
        hfsprogs
        libgnome-keyring0
        libsecret-tools
        samba
        seahorse
        syslinux-utils
        usb-creator-gtk
        vainfo
        x11vnc

        # hardware
        blueman
        btscanner
        ddcutil
        guvcview
        nvme-cli

        # automation
        devilspie2
        python3-xlib
        sxhkd
        wmctrl
        xautomation
        xclip
        xdotool

    )

    apt_install_packages "desktop essentials" "${DESKTOP_ESSENTIALS[*]}"

    # buggy (replaced with Rambox)
    apt_remove_packages caprine

    # replaced with official client
    apt_remove_packages teams-for-linux teams-insiders

    DEVELOPMENT=(
        build-essential
        cmake
        code
        d-feet
        dbeaver-ce
        devscripts
        equivs
        git
        git-cola
        meld
        msmtp
        nodejs
        php
        php-bcmath
        php-cli
        php-curl
        php-dev
        php-fpm
        php-gd
        php-gettext
        php-imagick
        php-imap
        php-intl
        php-json
        php-mbstring
        php-mcrypt?
        php-memcache
        php-memcached
        php-mysql
        php-pear
        php-soap
        php-sqlite3
        php-xdebug
        php-xml
        php-xmlrpc
        php-zip
        python
        python-dateutil
        python-dev
        python-mysqldb
        python-pip
        python-requests
        python3
        python3-dateutil
        python3-dev
        python3-mysqldb
        python3-pip
        python3-requests
        ruby
        s-nail
        shellcheck
        sublime-merge
        sublime-text
        trickle
        yarn

        # Lua
        lua5.1
        lua-posix
    )

    apt_install_packages "development" "${DEVELOPMENT[*]}"

    [ "$LOW_RAM" -eq "1" ] || apt_install_packages "development services" "\
apache2 \
apache2-doc \
mariadb-server \
mongodb-org \
"

    if apt_package_available powershell; then

        apt_install_packages "PowerShell" "powershell"
        apt_remove_packages powershell-preview

    else

        apt_install_packages "PowerShell" "powershell-preview"

    fi

    [ "$LOW_RAM" -eq "1" ] || is_virtual || apt_install_packages "QEMU/KVM" "bridge-utils libvirt-bin qemu-kvm virt-manager"
    [ "$LOW_RAM" -eq "1" ] || apt_install_packages "Docker CE" "docker-ce docker-ce-cli containerd.io"

    case "${XDG_CURRENT_DESKTOP:-}" in

    XFCE)

        XFCE_EXTRAS=(
            # sound
            libcanberra-gtk-module
            libcanberra-gtk3-module
            sox
            ubuntu-sounds

            # desktop essentials
            plank
            xfce4-battery-plugin
            xfce4-cpufreq-plugin
            xfce4-sensors-plugin
            xscreensaver
            xscreensaver-data
            xscreensaver-data-extra
            xscreensaver-gl
            xscreensaver-gl-extra

            # the version in the repo breaks logout/suspend/etc.
            #xiccd
        )

        apt_install_packages "Xfce extras" "${XFCE_EXTRAS[@]}"

        apt_remove_packages light-locker

        ;;

    esac

    if ! has_argument "--skip-debs"; then

        # the Ubuntu package doesn't work
        apt_package_installed ttf-mscorefonts-installer || apt_install_deb "http://ftp.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.7_all.deb"

        apt_install_deb "https://www.rescuetime.com/installers/rescuetime_current_amd64.deb"
        apt_install_deb "https://zoom.us/client/latest/zoom_amd64.deb"

        console_message "Looking up deb package URLs" "" "$CYAN"

        DEB_URLS=()
        DEB_URLS+=("$(get_urls_from_url "https://api.github.com/repos/AppImage/appimaged/releases/tags/continuous" '_amd64\.deb$' | head -n1)")
        DEB_URLS+=("$(get_urls_from_url "https://api.github.com/repos/careteditor/releases-beta/releases/latest" '\.deb$' | head -n1)")
        DEB_URLS+=("$(get_urls_from_url "https://code-industry.net/free-pdf-editor/" '.*-qt5\.amd64\.deb$' | head -n1)")
        DEB_URLS+=("$(get_urls_from_url "https://api.github.com/repos/Motion-Project/motion/releases/latest" '.*'"$DISTRIB_CODENAME"'.*_amd64\.deb$' | head -n1)")
        DEB_URLS+=("$(get_urls_from_url "https://api.github.com/repos/ramboxapp/community-edition/releases/latest" '.*-amd64\.deb$' | head -n1)")
        DEB_URLS+=("$(get_urls_from_url "https://slack.com/intl/en-au/downloads/instructions/ubuntu" '.*\.deb$' | head -n1)")
        DEB_URLS+=("$(get_urls_from_url "https://api.github.com/repos/hovancik/stretchly/releases/latest" '_amd64\.deb$' | head -n1)")
        DEB_URLS+=("$(get_urls_from_url "https://api.github.com/repos/KryDos/todoist-linux/releases/latest" '_amd64\.deb$' | head -n1)")

        for DEB_URL in "${DEB_URLS[@]}"; do

            apt_install_deb "$DEB_URL"
            console_message "Queued for download:" "${NO_WRAP}${DEB_URL}${WRAP}" "$BOLD" "$YELLOW"

        done

    fi

    dev_install_packages Y APT_INSTALLED

    # we're about to install ntp
    if command_exists timedatectl; then

        sudo timedatectl set-ntp no || true

    fi

    brew_check
    brew_mark_cache_clean
    brew_check_taps

    brew_queue_formulae "essentials" "\
unison \
"

    brew_queue_formulae "development" "\
shfmt \
"

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

    if apt_package_installed "appimaged" && ! user_service_running appimaged; then

        systemctl --user add-wants default.target appimaged
        systemctl --user start appimaged

    fi

    if apt_package_installed "samba"; then

        console_message "Configuring Samba..." "" "$CYAN"

        if apt_package_just_installed "samba"; then

            "$ROOT_DIR/linux/dev-samba-configure.sh"

        fi

        sudo pdbedit -L | grep "^$USER:" >/dev/null || {

            sudo smbpasswd -san "$USER" &&
                echoc "${BOLD}WARNING: Samba user $USER has been added with no password${RESET} (use smbpasswd to create one)" "$RED"

        }

    fi

    if apt_package_installed "ntp"; then

        console_message "Configuring NTP..." "" "$CYAN"

        safe_symlink "$CONFIG_DIR/ntp.conf" "/etc/ntp.conf" Y Y

        if [ -f "/etc/apparmor.d/usr.sbin.ntpd" ] && ! [ -e "/etc/apparmor.d/disable/usr.sbin.ntpd" ]; then

            sudo ln -sv "../usr.sbin.ntpd" "/etc/apparmor.d/disable/usr.sbin.ntpd"

            sudo apparmor_parser -R "/etc/apparmor.d/usr.sbin.ntpd" 2>/dev/null || true

        fi

        sudo service ntp restart

    fi

    if apt_package_installed "apache2"; then

        console_message "Configuring Apache..." "" "$CYAN"

        dir_make_and_own /var/www/virtual

        mkdir -p "/var/www/virtual/127.0.0.1"
        safe_symlink "/var/www/virtual/127.0.0.1" "/var/www/virtual/localhost"

        safe_symlink "$CONFIG_DIR/www" "/var/www/virtual/127.0.0.1/html" N Y

        # TODO: abstract this to a function like is_user_in_group
        groups | grep -Eq '(\s|^)(www-data)(\s|$)' || sudo adduser "$(id -un)" "www-data"
        groups "www-data" | grep -Eo '[^:]+$' | grep -Eq '(\s|^)'"$(id -gn)"'(\s|$)' || sudo adduser "www-data" "$(id -gn)"

        safe_symlink "$CONFIG_DIR/apache2-virtual.conf" "/etc/apache2/sites-available/000-virtual-linacreative.conf" Y Y

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

        safe_symlink "$CONFIG_DIR/mariadb.cnf" "/etc/mysql/mariadb.conf.d/60-linacreative.cnf" Y Y

        # reload isn't enough
        sudo service mysql restart

    fi

    if ! apt_package_installed "python-wnck"; then

        apt_install_deb "http://old-releases.ubuntu.com/ubuntu/pool/main/g/gnome-python-desktop/python-wnck_2.32.0-0ubuntu6_amd64.deb"

        apt_process_queue

    fi

    # non-apt installations

    brew_process_queue

    DEV_JUST_INSTALLED=()
    dev_process_queue DEV_JUST_INSTALLED

    if [ "${#DEV_JUST_INSTALLED[@]}" -gt "0" ]; then

        APT_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")
        APT_JUST_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")

    fi

    ESPANSO_PATH="/usr/local/bin/espanso"
    ESPANSO_TEMP="$TEMP_DIR/espanso"
    rm -f "$ESPANSO_TEMP"

    console_message "Downloading latest espanso binary" "" "$CYAN"
    curl -sSL "https://github.com/federico-terzi/espanso/releases/latest/download/espanso-linux.tar.gz" | tar -xz --overwrite -C "$TEMP_DIR" && [ -x "$ESPANSO_TEMP" ] || die "Error downloading espanso"

    if ! cmp -s "$ESPANSO_PATH" "$ESPANSO_TEMP"; then

        console_message "Installing latest espanso" "" "$CYAN"

        if user_service_running espanso; then

            espanso stop
            rm -f "$ESPANSO_PATH"
            mv -v "$ESPANSO_TEMP" "$ESPANSO_PATH"
            espanso start

        else

            rm -f "$ESPANSO_PATH"
            mv -v "$ESPANSO_TEMP" "$ESPANSO_PATH"

        fi

    else

        rm -f "$ESPANSO_TEMP"

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

    # final tasks

    dev_apply_system_config

    if apt_package_installed "cups-browsed"; then

        # prevent AirPrint printers being added automatically
        sudo systemctl disable --now cups-browsed >/dev/null 2>&1 || die "Error disabling cups-browsed service"

    fi

    if apt_package_installed "virtualbox-[0-9.]+"; then

        console_message "Configuring VirtualBox..." "" "$CYAN"

        groups | grep -Eq '(\s|^)(vboxusers)(\s|$)' || sudo adduser "$(id -un)" "vboxusers"

        sudo systemctl disable --now vboxautostart-service >/dev/null 2>&1 ||
            die "Error disabling vboxautostart-service service"

        VBoxManage setproperty loghistorycount 20

    fi

    if apt_package_installed "docker-ce"; then

        sudo groupadd -f docker >/dev/null 2>&1 && sudo adduser "$USER" docker >/dev/null 2>&1 || die "Error adding $USER to docker group"

    fi

    # if apt_package_installed "libgtk-3-dev"; then

    #     gsettings set org.gtk.Settings.Debug enable-inspector-keybinding true

    # fi

    # workaround for Synergy bug: https://github.com/symless/synergy-core/issues/6481
    HOLD_PACKAGES=(libx11-6 libx11-data libx11-dev libx11-doc libx11-xcb-dev libx11-xcb1)

    for i in "${!HOLD_PACKAGES[@]}"; do

        if ! apt_package_installed "${HOLD_PACKAGES[$i]}"; then

            unset "HOLD_PACKAGES[$i]"

        fi

    done

    if [ "${#HOLD_PACKAGES[@]}" -gt "0" ]; then

        if system_service_exists "synergy"; then

            if dpkg-query -f '${Version}\n' -W "${HOLD_PACKAGES[@]}" | grep -Eq "$(sed_escape_search "2:1.6.4-3ubuntu0.2")"; then

                VERSIONED_HOLD_PACKAGES=()

                for p in "${HOLD_PACKAGES[@]}"; do

                    VERSIONED_HOLD_PACKAGES+=("$p=2:1.6.4-3ubuntu0.1")

                done

                console_message "Downgrading from ${BOLD}2:1.6.4-3ubuntu0.2${RESET} to ${BOLD}2:1.6.4-3ubuntu0.1${RESET} and marking as held:" "${HOLD_PACKAGES[*]}" "$BOLD" "$RED"

                sudo apt-get "${APT_GET_OPTIONS[@]}" --allow-downgrades install "${VERSIONED_HOLD_PACKAGES[@]}"

                sudo apt-mark hold "${HOLD_PACKAGES[@]}" >/dev/null

            fi

        else

            sudo apt-mark unhold "${HOLD_PACKAGES[@]}" >/dev/null

        fi

    fi

    "$ROOT_DIR/bash/dev-system-update.sh"

    apt_purge

    # ALL_PACKAGES=($(printf '%s\n' "${APT_INSTALLED[@]}" | grep -Eo '[^/]+$' | sort | uniq))
    # console_message "${#ALL_PACKAGES[@]} installed $(single_or_plural ${#ALL_PACKAGES[@]} "package is" "packages are") managed by $(basename "$0"):" "" "$BLUE"
    # COLUMNS="$(tput cols)" && apt_pretty_packages "$(printf '%s\n' "${ALL_PACKAGES[@]}" | column -c "$COLUMNS")" || apt_pretty_packages "${ALL_PACKAGES[*]}" Y

    if apt_package_available "linux-generic-hwe-$DISTRIB_RELEASE" && apt_package_available "xserver-xorg-hwe-$DISTRIB_RELEASE" && ! apt_package_installed "linux-generic-hwe-$DISTRIB_RELEASE" && ! apt_package_installed "xserver-xorg-hwe-$DISTRIB_RELEASE"; then

        echo
        console_message "To use the Ubuntu LTS enablement stack, but only for X server, run:" "sudo apt-get install linux-generic-hwe-${DISTRIB_RELEASE}- xserver-xorg-hwe-$DISTRIB_RELEASE" "$BOLD" "$CYAN"

    fi

    exit

}
