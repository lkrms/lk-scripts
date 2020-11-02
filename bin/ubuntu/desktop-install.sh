#!/bin/bash
# shellcheck disable=SC1090,SC2206,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"
. "$SCRIPT_DIR/../../bash/common-apt"
. "$SCRIPT_DIR/../../bash/common-dev"
. "$SCRIPT_DIR/../../bash/common-homebrew"

lk_assert_is_ubuntu
lk_assert_is_desktop
lk_assert_not_root

# allow this script to be changed while it's running
{
    lk_sudo_offer_nopasswd

    disable_update_motd

    # apply all available preferences in $CONFIG_DIR/apt/preferences.d
    apt_apply_preferences suppress-bsd-mailx suppress-deepin-notifications suppress-libapache2-mod-php suppress-youtube-dl withhold-proposed-packages

    lk_safe_symlink "$CONFIG_DIR/apt.conf" "/etc/apt/apt.conf.d/90-linacreative" Y Y

    lk_safe_symlink "$CONFIG_DIR/sysctl.d/90-inotify-maximum-watches.conf" "/etc/sysctl.d/90-inotify-maximum-watches.conf" Y

    # get underway without an immediate index update
    apt_mark_cache_clean

    # ensure all of Ubuntu's repositories are available (including "backports" and "proposed" archives)
    apt_enable_ubuntu_repository main updates backports proposed
    apt_enable_ubuntu_repository restricted updates backports proposed
    apt_enable_ubuntu_repository universe updates backports proposed
    apt_enable_ubuntu_repository multiverse updates backports proposed

    APT_PREREQ+=(
        trash-cli
    )

    apt_check_prerequisites

    # seed debconf database with answers
    sudo debconf-set-selections <<EOF
kdump-tools kdump-tools/use_kdump boolean true
kexec-tools kexec-tools/load_kexec boolean false
libc6 libraries/restart-without-asking boolean true
libpam0g libraries/restart-without-asking boolean true
EOF

    MEMORY_SIZE_MB=-1
    LOW_RAM=0

    if ! lk_is_virtual; then

        MEMORY_SIZE_MB="$(get_memory_size)"

        [ "$MEMORY_SIZE_MB" -ge "8192" ] || {
            LOW_RAM=1
            lk_console_message "Because this system has less than 8GB of RAM, some packages will not be offered" "$RED"
        }

    else

        lk_console_message "Because this is a virtual machine, some packages will not be offered" "$RED"

    fi

    # register PPAs (note: this doesn't add them to the system straightaway; they are added on-demand if/when the relevant packages are actually installed)
    apt_register_ppa "caffeine-developers/ppa" "caffeine"
    apt_register_ppa "git-core/ppa" "git" N N
    apt_register_ppa "heyarje/makemkv-beta" "makemkv-*"
    apt_register_ppa "hluk/copyq" "copyq"
    apt_register_ppa "inkscape.dev/stable" "inkscape"
    apt_register_ppa "intel-opencl/intel-opencl" "intel-opencl-icd" N N
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
    apt_register_repository displaycal "https://download.opensuse.org/repositories/home:/fhoech/xUbuntu_18.04/Release.key" "deb https://download.opensuse.org/repositories/home:/fhoech/xUbuntu_$DISTRIB_RELEASE/ /" "release l=home:fhoech" "displaycal"
    apt_register_repository docker "https://download.docker.com/linux/ubuntu/gpg" "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable" "origin download.docker.com" "docker-ce* containerd.io"
    apt_register_repository google-chrome "https://dl.google.com/linux/linux_signing_key.pub" "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" "origin dl.google.com" "google-chrome-*"
    apt_register_repository microsoft "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/ubuntu/$DISTRIB_RELEASE/prod $DISTRIB_CODENAME main" "release o=microsoft-ubuntu-$DISTRIB_CODENAME-prod $DISTRIB_CODENAME,l=microsoft-ubuntu-$DISTRIB_CODENAME-prod $DISTRIB_CODENAME" "powershell*" Y
    apt_register_repository mkvtoolnix "https://mkvtoolnix.download/gpg-pub-moritzbunkus.txt" "deb https://mkvtoolnix.download/ubuntu/ $DISTRIB_CODENAME main" "origin mkvtoolnix.download" "mkvtoolnix*"
    apt_register_repository signal "https://updates.signal.org/desktop/apt/keys.asc" "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" "origin updates.signal.org" "signal-desktop"
    apt_register_repository skype-stable "https://repo.skype.com/data/SKYPE-GPG-KEY" "deb [arch=amd64] https://repo.skype.com/deb stable main" "origin repo.skype.com" "skypeforlinux"
    apt_register_repository spotify "931FF8E79F0876134EDDBDCCA87FF9DF48BF1C90 2EBF997C15BDA244B6EBF5D84773BD5E130D1D45" "deb http://repository.spotify.com stable non-free" "origin repository.spotify.com" "spotify-client"
    apt_register_repository sublime-text "https://download.sublimetext.com/sublimehq-pub.gpg" "deb https://download.sublimetext.com/ apt/stable/" "origin download.sublimetext.com" "sublime-*"
    apt_register_repository teams "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/ms-teams stable main" "release o=ms-teams stable,l=ms-teams stable" "teams teams-*"
    apt_register_repository typora "https://typora.io/linux/public-key.asc" "deb https://typora.io/linux ./" "origin typora.io" "typora"
    apt_register_repository vscode "https://packages.microsoft.com/keys/microsoft.asc" "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" "release o=vscode stable,l=vscode stable" "code code-*"

    # otherwise pip, pip3, npm packages (and composer) will be skipped until next run
    APT_ESSENTIALS+=(
        nodejs
        php-cli
        python-pip
        python3-pip
    )

    ! lk_command_exists check-language-support || APT_ESSENTIALS+=($(check-language-support --show-installed))

    apt_check_essentials

    DESKTOP_PREREQ=(
        # OpenConnect (build) dependencies
        autoconf
        automake
        gettext
        libgnutls-dev?
        libgnutls28-dev?
        libproxy-dev
        libtool
        libxml2-dev
        pkg-config
        vpnc-scripts
        zlib1g-dev

        # barrier (build) dependencies
        libavahi-compat-libdnssd-dev
        libcurl4-openssl-dev
        libqt4-dev
        libssl-dev
        libx11-dev
        libxtst-dev
        qtbase5-dev

        # xiccd (build) dependencies
        libcolord-dev
        libx11-dev
        libxrandr-dev

        # QuickTile dependencies
        python
        python-dbus
        python-gtk2
        python-setuptools
        python-wnck?
        python-xlib

        # espanso dependencies
        libxdo3
        libxtst6
        xclip
    )

    apt_install_packages "application dependencies" "${DESKTOP_PREREQ[*]}" N

    DESKTOP_ESSENTIALS=(
        # basics
        caffeine
        copyq
        deepin-screenshot
        firefox
        galculator
        geany
        ghostwriter
        gimp
        google-chrome-stable
        inkscape
        keepassxc
        libreoffice
        qpdfview
        remmina
        scribus
        signal-desktop
        skypeforlinux
        speedcrunch
        spotify-client
        teams
        thunderbird
        transmission
        transmission-cli
        typora
        xul-ext-lightning

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
        clementine
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

        # automation
        devilspie2
        python3-xlib
        sxhkd
        wmctrl
        xautomation
        xclip
        xdotool

    )

    lk_is_virtual || DESKTOP_ESSENTIALS+=(
        blueman
        btscanner
        clinfo
        ddcutil
        guvcview
        intel-gpu-tools
        intel-opencl-icd
        linssid
        nvme-cli
        tlp
        tlp-rdw
    )

    apt_install_packages "desktop essentials" "${DESKTOP_ESSENTIALS[*]}"

    # replaced with official client
    apt_remove_packages teams-for-linux teams-insiders

    # NB: ruby is installed as a prerequisite
    DEVELOPMENT=(
        # IDEs
        code
        dbeaver-ce
        sublime-text
        tidy

        # Node.js
        nodejs
        yarn

        # PHP
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

        # Python 2
        python
        python-dateutil
        python-dev
        python-mysqldb
        python-pip
        python-requests

        # Python 3
        python3
        python3-dateutil
        python3-dev
        python3-mysqldb
        python3-pip
        python3-requests

        # Bash et al.
        shellcheck

        # email delivery
        msmtp
        s-nail

        # testing
        trickle

        # version control
        git
        git-cola
        meld
        sublime-merge

        # Lua
        lua5.1
        lua-penlight
        lua-posix

        # GTK
        gtk-3-examples
        libgtk-3-dev

        # Linux-specific
        d-feet
    )

    DEVELOPMENT_SERVICES=(
        apache2
        apache2-doc
        mariadb-server
        mongodb-org
    )

    apt_install_packages "development" "${DEVELOPMENT[*]}"

    [ "$LOW_RAM" -eq "1" ] || apt_install_packages "development services" "${DEVELOPMENT_SERVICES[*]}"

    if apt_package_available powershell; then

        apt_install_packages "PowerShell" "powershell"
        apt_remove_packages powershell-preview

    else

        apt_install_packages "PowerShell" "powershell-preview"

    fi

    [ "$LOW_RAM" -eq "1" ] || lk_is_virtual || apt_install_packages "QEMU/KVM" "libvirt-bin libvirt-doc qemu-kvm virt-manager virtinst"
    [ "$LOW_RAM" -eq "1" ] || lk_is_virtual || apt_install_packages "Docker CE" "docker-ce docker-ce-cli containerd.io"

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

            # the version in the repo breaks logout/suspend/etc.
            #xiccd
        )

        apt_install_packages "Xfce extras" "${XFCE_EXTRAS[*]}"

        apt_remove_packages light-locker xfce4-indicator-plugin

        ;;

    esac

    if ! lk_has_arg "--skip-debs"; then

        DEB_URLS=(
            "https://www.rescuetime.com/installers/rescuetime_current_amd64.deb"
            "https://zoom.us/client/latest/zoom_amd64.deb"
        )

        # the Ubuntu package doesn't work
        apt_package_installed ttf-mscorefonts-installer || DEB_URLS+=("http://ftp.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.7_all.deb")

        lk_console_message "Looking up deb package URLs"

        DEB_URLS+=("$(lk_wget_uris "https://api.github.com/repos/AppImage/appimaged/releases/tags/continuous" | sed -E '/_amd64\.deb$/!d' | head -n1)")
        DEB_URLS+=("$(lk_wget_uris "https://api.github.com/repos/sindresorhus/caprine/releases/latest" | sed -E '/_amd64\.deb$/!d' | head -n1)")
        DEB_URLS+=("$(lk_wget_uris "https://api.github.com/repos/careteditor/releases-beta/releases/latest" | sed -E '/\.deb$/!d' | head -n1)")
        DEB_URLS+=("$(lk_wget_uris "https://code-industry.net/free-pdf-editor/" | sed -E '/.*-qt5\.amd64\.deb$/!d' | head -n1)")
        DEB_URLS+=("$(lk_wget_uris "https://api.github.com/repos/Motion-Project/motion/releases" | sed -E '/.*'"$DISTRIB_CODENAME"'.*_amd64\.deb$/!d' | head -n1)")
        DEB_URLS+=("$(lk_wget_uris "https://slack.com/intl/en-au/downloads/instructions/ubuntu" | sed -E '/.*\.deb$/!d' | head -n1)")
        DEB_URLS+=("$(lk_wget_uris "https://api.github.com/repos/hovancik/stretchly/releases/latest" | sed -E '/_amd64\.deb$/!d' | head -n1)")
        DEB_URLS+=("$(lk_wget_uris "https://api.github.com/repos/KryDos/todoist-linux/releases/latest" | sed -E '/_amd64\.deb$/!d' | head -n1)")

        if [ "${XDG_CURRENT_DESKTOP:-}" = "XFCE" ]; then

            DEB_URLS+=(
                "http://ftp.debian.org/debian/pool/main/libj/libjpeg-turbo/libjpeg62-turbo_1.5.2-2+b1_amd64.deb"
                "http://ftp.debian.org/debian/pool/main/x/xscreensaver/xscreensaver_5.42+dfsg1-1_amd64.deb"
                "http://ftp.debian.org/debian/pool/main/x/xscreensaver/xscreensaver-data_5.42+dfsg1-1_amd64.deb"
                "http://ftp.debian.org/debian/pool/main/x/xscreensaver/xscreensaver-data-extra_5.42+dfsg1-1_amd64.deb"
                "http://ftp.debian.org/debian/pool/main/x/xscreensaver/xscreensaver-gl_5.42+dfsg1-1_amd64.deb"
                "http://ftp.debian.org/debian/pool/main/x/xscreensaver/xscreensaver-gl-extra_5.42+dfsg1-1_amd64.deb"
            )

        fi

        for i in "${!DEB_URLS[@]}"; do

            DEB_URL="${DEB_URLS[$i]}"

            [ -n "$DEB_URL" ] || {
                unset "DEB_URLS[$i]"
                continue
            }

            apt_install_deb "$DEB_URL"

        done

        lk_echo_array "${DEB_URLS[@]}" | lk_console_list "Packages queued to download and install" "$BOLD$YELLOW"

    fi

    dev_install_packages Y APT_INSTALLED

    # we're about to install ntp
    if lk_command_exists timedatectl; then

        sudo timedatectl set-ntp no || true

    fi

    brew_check
    brew_mark_cache_clean
    brew_check_taps

    brew_queue_formulae "essentials" "\
unison \
"

    brew_queue_formulae "development" "\
git-filter-repo \
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

        lk_console_message "Configuring Samba..."

        if apt_package_just_installed "samba"; then

            "$LK_ROOT/linux/dev-samba-configure.sh"

        fi

        sudo pdbedit -L | grep "^$USER:" >/dev/null || {

            sudo smbpasswd -san "$USER" &&
                lk_echoc "${BOLD}WARNING: Samba user $USER has been added with no password${RESET} (use smbpasswd to create one)" "$RED"

        }

    fi

    if apt_package_installed "ntp"; then

        lk_console_message "Configuring NTP..."

        lk_safe_symlink "$CONFIG_DIR/ntp.conf" "/etc/ntp.conf" Y Y

        if [ -f "/etc/apparmor.d/usr.sbin.ntpd" ] && ! [ -e "/etc/apparmor.d/disable/usr.sbin.ntpd" ]; then

            sudo ln -sv "../usr.sbin.ntpd" "/etc/apparmor.d/disable/usr.sbin.ntpd"

            sudo apparmor_parser -R "/etc/apparmor.d/usr.sbin.ntpd" 2>/dev/null || true

        fi

        sudo service ntp restart

    fi

    if apt_package_installed "apache2"; then

        lk_console_message "Configuring Apache..."

        lk_maybe_install -d -o "$(id -un)" -g "$(id -gn)" /var/www/virtual

        mkdir -p "/var/www/virtual/127.0.0.1"
        lk_safe_symlink "/var/www/virtual/127.0.0.1" "/var/www/virtual/localhost"

        lk_safe_symlink "$CONFIG_DIR/www" "/var/www/virtual/127.0.0.1/html" N Y

        # TODO: abstract this to a function like is_user_in_group
        groups | grep -Eq '(\s|^)(www-data)(\s|$)' || sudo adduser "$(id -un)" "www-data"
        groups "www-data" | grep -Eo '[^:]+$' | grep -Eq '(\s|^)'"$(id -gn)"'(\s|$)' || sudo adduser "www-data" "$(id -gn)"

        lk_safe_symlink "$CONFIG_DIR/apache2-virtual.conf" "/etc/apache2/sites-available/000-virtual-linacreative.conf" Y Y

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

        lk_console_message "Configuring MariaDB..."

        lk_safe_symlink "$CONFIG_DIR/mariadb.cnf" "/etc/mysql/mariadb.conf.d/60-linacreative.cnf" Y Y

        # reload isn't enough
        sudo service mysql restart

    fi

    if ! apt_package_installed "python-wnck"; then

        apt_install_deb "http://old-releases.ubuntu.com/ubuntu/pool/main/g/gnome-python-desktop/python-wnck_2.32.0-0ubuntu6_amd64.deb"

        apt_process_queue

    fi

    ! apt_package_installed "tidy" || lk_safe_symlink "$CONFIG_DIR/tidy.conf" "/etc/tidy.conf" Y Y

    # non-apt installations

    brew_process_queue

    lk_install_gnu_commands

    DEV_JUST_INSTALLED=()
    dev_process_queue DEV_JUST_INSTALLED

    if [ "${#DEV_JUST_INSTALLED[@]}" -gt "0" ]; then

        APT_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")
        APT_JUST_INSTALLED+=("${DEV_JUST_INSTALLED[@]}")

    fi

    ESPANSO_PATH="/usr/local/bin/espanso"
    ESPANSO_TEMP="$TEMP_DIR/espanso"
    rm -f "$ESPANSO_TEMP"

    lk_console_message "Downloading latest espanso binary"
    curl -sSL "https://github.com/federico-terzi/espanso/releases/latest/download/espanso-linux.tar.gz" | tar -xz --overwrite -C "$TEMP_DIR" && [ -x "$ESPANSO_TEMP" ] || lk_die "Error downloading espanso"

    if ! cmp -s "$ESPANSO_PATH" "$ESPANSO_TEMP"; then

        lk_console_message "Installing latest espanso"

        if pgrep -x espanso >/dev/null; then

            espanso stop
            rm -f "$ESPANSO_PATH"
            mv -v "$ESPANSO_TEMP" "$ESPANSO_PATH"
            nohup espanso daemon </dev/null >/dev/null 2>&1 &
            disown

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
        sudo systemctl disable --now cups-browsed >/dev/null 2>&1 || lk_die "Error disabling cups-browsed service"

    fi

    if apt_package_installed "virtualbox-[0-9.]+"; then

        lk_console_message "Configuring VirtualBox..."

        groups | grep -Eq '(\s|^)(vboxusers)(\s|$)' || sudo adduser "$(id -un)" "vboxusers"

        sudo systemctl disable --now vboxautostart-service >/dev/null 2>&1 ||
            lk_die "Error disabling vboxautostart-service service"

        VBoxManage setproperty loghistorycount 20

    fi

    if apt_package_installed "docker-ce"; then

        sudo groupadd -f docker >/dev/null 2>&1 && sudo adduser "$USER" docker >/dev/null 2>&1 || lk_die "Error adding $USER to docker group"

    fi

    "$LK_ROOT/bash/dev-system-update.sh"

    apt_purge

    # ALL_PACKAGES=($(printf '%s\n' "${APT_INSTALLED[@]}" | grep -Eo '[^/]+$' | sort | uniq))
    # lk_console_message "${#ALL_PACKAGES[@]} installed $(lk_maybe_plural ${#ALL_PACKAGES[@]} "package is" "packages are") managed by $(basename "$0"):" "$BLUE"
    # COLUMNS="$(tput cols)" && apt_pretty_packages "$(printf '%s\n' "${ALL_PACKAGES[@]}" | column -c "$COLUMNS")" || apt_pretty_packages "${ALL_PACKAGES[*]}" Y

    if apt_package_available "linux-generic-hwe-$DISTRIB_RELEASE" && apt_package_available "xserver-xorg-hwe-$DISTRIB_RELEASE" && ! apt_package_installed "linux-generic-hwe-$DISTRIB_RELEASE" && ! apt_package_installed "xserver-xorg-hwe-$DISTRIB_RELEASE"; then

        echo
        lk_console_item "To use the Ubuntu LTS enablement stack, but only for X server, run:" "sudo apt-get install linux-generic-hwe-${DISTRIB_RELEASE}- xserver-xorg-hwe-$DISTRIB_RELEASE" "$BOLD$CYAN"

    fi

    exit

}
