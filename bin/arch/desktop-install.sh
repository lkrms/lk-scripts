#!/bin/bash
# shellcheck disable=SC1090,SC2015,SC2016,SC2034,SC2046,SC2174,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_is_desktop
assert_not_root

PAC_INSTALL=()
AUR_INSTALL=()

PAC_KEEP=(
    asciicast2gif
    gnome-python-desktop
    masterpdfeditor
    python2-xlib
    quicktile-git
    r8152-dkms # common USB / USB-C NIC
)

PAC_REMOVE=(
    xfce4-screensaver # buggy and insecure
)

# hardware-related
is_virtual || {
    PAC_INSTALL+=(
        guvcview  # webcam utility
        i2c-tools # provides i2c-dev module, required by ddcutil
        linssid   # wireless scanner

        # "general-purpose computing on graphics processing units" (GPGPU)
        # required to run GPU benchmarks, e.g. in Geekbench
        clinfo
        intel-compute-runtime

        # required to use Intel Quick Sync Video in FFmpeg
        intel-media-sdk
    )
    AUR_INSTALL+=(
        ddcutil
    )
}
AUR_INSTALL+=(
    brother-hl5450dn
    brother-hll3230cdw
)

# terminal-based
PAC_INSTALL+=(
    # shells
    asciinema
    bash-completion
    byobu
    ksh
    zsh

    # utilities
    bc
    cdrtools
    jq
    lsb-release
    mediainfo
    p7zip
    pv
    sox
    stow
    unison
    unzip
    vim
    wimlib

    # networking
    bridge-utils
    openconnect
    traceroute
    whois

    # monitoring
    atop
    glances
    htop # 'top' alternative
    iotop
    ps_mem
    sysstat

    # network monitoring
    iftop    # shows network traffic by service and host
    iproute2 # (ifstat) dumps network statistics by interface
    nethogs  # groups bandwidth by process ('nettop')
    nload    # shows bandwidth by interface

    # system
    acme.sh
    at
    cloud-utils
    cronie
    hwinfo
    sysfsutils
)

AUR_INSTALL+=(
    #asciicast2gif
    git-filter-repo
    powershell-bin
    vpn-slice
)

# desktop
PAC_INSTALL+=(
    caprine
    catfish
    copyq
    evince
    firefox
    firefox-i18n-en-gb
    flameshot
    freerdp
    galculator
    geany
    gimp
    gucharmap
    inkscape
    keepassxc
    libreoffice-fresh
    libreoffice-fresh-en-gb
    nextcloud-client
    nomacs # ristretto alternative
    qpdfview
    remmina
    scribus
    speedcrunch
    system-config-printer
    thunderbird
    thunderbird-i18n-en-gb
    thunderbird-i18n-en-us
    transmission-cli
    transmission-gtk
    trash-cli

    # because there's always That One Website
    flashplugin

    # PDF
    ghostscript  # PDF/PostScript processor
    mupdf-tools  # PDF manipulation tools
    pandoc       # text conversion tool (e.g. Markdown to PDF)
    poppler      # PDF tools like pdfimages
    pstoedit     # converts PDF/PostScript to vector formats
    texlive-core # required for PDF output from pandoc

    # photography
    geeqie
    rapid-photo-downloader

    # search (Recoll)
    antiword            # Word
    aspell-en           # English stemming
    catdoc              # Excel, Powerpoint
    perl-image-exiftool # EXIF metadata
    python-lxml         # spreadsheets
    recoll
    unrtf

    # multimedia - playback
    clementine
    libdvdcss
    libdvdnav
    libvpx
    vlc

    # multimedia - audio
    abcde
    audacity
    beets
    python-eyed3

    # multimedia - video
    ffmpeg
    handbrake
    handbrake-cli
    mkvtoolnix-cli
    mkvtoolnix-gui
    mpv
    rtmpdump
    youtube-dl

    # system
    dconf-editor
    displaycal
    gparted
    guake
    libsecret   # secret-tool
    libva-utils # vainfo
    samba
    seahorse
    syslinux
    vdpauinfo
    x11vnc

    # automation
    sxhkd
    wmctrl
    xautomation
    xclip
    xdotool
    xorg-xev
)

AUR_INSTALL+=(
    espanso
    ghostwriter
    google-chrome
    #masterpdfeditor
    skypeforlinux-stable-bin
    spotify
    teams
    todoist-electron
    trimage
    #ttf-ms-win10
    typora

    # multimedia - video
    makemkv

    # balena-etcher dependency
    electron7-bin

    # system
    balena-etcher
    hfsprogs

    # automation
    devilspie2
    xorg-xkbprint

    # these need to be installed in this order
    #gconf
    #gnome-python
    #gnome-python-desktop #i.e. python2-wnck
    #python2-xlib
    #quicktile-git
)

# development
PAC_INSTALL+=(
    autopep8
    bash-language-server
    dbeaver
    eslint
    python-pylint
    qcachegrind
    tidy
    ttf-font-awesome
    ttf-ionicons

    # email
    msmtp     # smtp client
    msmtp-mta # sendmail alias for msmtp
    s-nail    # mail and mailx commands

    #
    git
    meld

    #
    jdk11-openjdk
    jre11-openjdk

    #
    nodejs
    npm
    yarn

    #
    composer
    php
    php-gd
    php-imagick
    php-imap
    php-intl
    php-memcache
    php-memcached
    php-sqlite
    xdebug

    #
    mysql-python
    python
    python-dateutil
    python-pip
    python-requests
    python-virtualenv
    python2

    #
    shellcheck
    shfmt

    #
    lua
    lua-penlight

    # platforms
    aws-cli
)

AUR_INSTALL+=(
    postman
    sublime-text-dev
    trickle
    visual-studio-code-bin

    #
    git-cola
    sublime-merge

    #
    php-box
    php-compat-info

    # platforms
    azure-cli
    azure-functions-core-tools-bin
    sfdx-cli
    wp-cli
)

# development services
PAC_INSTALL+=(
    apache
    mariadb
    php-fpm
)

AUR_INSTALL+=(
    mongodb-bin
)

# VMs and containers
PAC_INSTALL+=(
    # libvirt
    dnsmasq
    ebtables
    libvirt
    qemu
    qemu-arch-extra # includes UEFI firmware, among other goodies
    virt-manager

    # docker
    docker
)

{

    ! offer_sudo_password_bypass ||
        {
            lk_console_message "Disabling password-based login as root"
            sudo passwd -l root

            lk_console_message "Disabling polkit password prompts"
            ! sudo test -d "/etc/polkit-1/rules.d" ||
                sudo test -e "/etc/polkit-1/rules.d/49-wheel.rules" ||
                sudo tee "/etc/polkit-1/rules.d/49-wheel.rules" <<EOF >/dev/null
// Allow any user in the 'wheel' group to take any action without
// entering a password.
polkit.addRule(function (action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
        }

    PAC_TO_REMOVE=($(comm -12 <(pacman -Qq | sort | uniq) <(lk_echo_array "${PAC_REMOVE[@]}" | sort | uniq)))
    [ "${#PAC_TO_REMOVE[@]}" -eq "0" ] || {
        lk_console_message "Removing packages"
        sudo pacman -R "${PAC_TO_REMOVE[@]}"
    }

    PAC_TO_MARK_EXPLICIT=($(comm -12 <(pacman -Qdq | sort | uniq) <(lk_echo_array "${PAC_INSTALL[@]}" "${AUR_INSTALL[@]}" ${PAC_KEEP[@]+"${PAC_KEEP[@]}"} | sort | uniq)))
    [ "${#PAC_TO_MARK_EXPLICIT[@]}" -eq "0" ] || {
        lk_console_message "Setting install reasons"
        sudo pacman -D --asexplicit "${PAC_TO_MARK_EXPLICIT[@]}"
    }

    PAC_TO_INSTALL=($(comm -13 <(pacman -Qeq | sort | uniq) <(lk_echo_array "${PAC_INSTALL[@]}" | sort | uniq)))
    [ "${#PAC_TO_INSTALL[@]}" -eq "0" ] || {
        lk_console_message "Installing new packages from repo"
        sudo pacman -Sy "${PAC_TO_INSTALL[@]}"
    }

    ! PAC_TO_PURGE=($(pacman -Qdttq)) ||
        [ "${#PAC_TO_PURGE[@]}" -eq "0" ] ||
        {
            lk_echo_array "${PAC_TO_PURGE[@]}" | lk_console_list "Orphaned package(s)"
            ! get_confirmation "Purge?" ||
                sudo pacman -Rns "${PAC_TO_PURGE[@]}"
        }

    lk_console_message "Upgrading installed packages"
    sudo pacman -Syu

    AUR_TO_INSTALL=($(comm -13 <(pacman -Qeq | sort | uniq) <(lk_echo_array "${AUR_INSTALL[@]}" | sort | uniq)))
    [ "${#AUR_TO_INSTALL[@]}" -eq "0" ] || {
        lk_console_message "Installing new packages from AUR"
        yay -Sy --aur "${AUR_TO_INSTALL[@]}"
    }

    lk_console_message "Upgrading installed AUR packages"
    yay -Syu --aur

    SUDO_OR_NOT=1 lk_apply_setting "/etc/ssh/sshd_config" "PasswordAuthentication" "no" " " "#" " " &&
        SUDO_OR_NOT=1 lk_apply_setting "/etc/ssh/sshd_config" "AcceptEnv" "LANG LC_*" " " "#" " " &&
        sudo systemctl enable --now sshd || true

    sudo systemctl enable --now atd || true

    sudo systemctl enable --now cronie || true

    sudo systemctl enable --now ntpd || true

    sudo systemctl enable --now org.cups.cupsd || true

    SUDO_OR_NOT=1 lk_apply_setting "/etc/bluetooth/main.conf" "AutoEnable" "true" "=" "#" &&
        sudo systemctl enable --now bluetooth

    SUDO_OR_NOT=1 lk_apply_setting "/etc/conf.d/libvirt-guests" "ON_SHUTDOWN" "shutdown" "=" "# " &&
        SUDO_OR_NOT=1 lk_apply_setting "/etc/conf.d/libvirt-guests" "SHUTDOWN_TIMEOUT" "300" "=" "# " &&
        sudo usermod --append --groups libvirt,kvm "$USER" &&
        {
            [ -e "/etc/qemu/bridge.conf" ] || {
                sudo mkdir -p "/etc/qemu" &&
                    echo "allow all" | sudo tee "/etc/qemu/bridge.conf" >/dev/null
            }
        } &&
        sudo systemctl enable --now libvirtd libvirt-guests || true

    sudo usermod --append --groups docker "$USER" &&
        sudo systemctl enable --now docker || true

    { sudo test -d "/var/lib/mysql/mysql" ||
        sudo mariadb-install-db --user="mysql" --basedir="/usr" --datadir="/var/lib/mysql"; } &&
        sudo systemctl enable --now mysqld || true

    SUDO_OR_NOT=1

    for PHP_EXT in bcmath curl gd gettext imap intl mysqli pdo_sqlite soap sqlite3 xmlrpc zip; do
        lk_enable_entry "/etc/php/php.ini" "extension=$PHP_EXT" ";"
    done
    lk_enable_entry "/etc/php/php.ini" "zend_extension=opcache" ";"
    function apply_php_setting() {
        lk_apply_setting "${PHP_INI_FILE:-/etc/php/php.ini}" "$1" "$2" " = " ";" " "
    }
    sudo mkdir -pm700 "/var/cache/php/opcache" &&
        sudo chown "http:" "/var/cache/php/opcache"
    apply_php_setting "memory_limit" "128M"
    apply_php_setting "error_reporting" "E_ALL"
    apply_php_setting "display_errors" "On"
    apply_php_setting "display_startup_errors" "On"
    apply_php_setting "log_errors" "Off"
    apply_php_setting "opcache.memory_consumption" "512"
    apply_php_setting "opcache.file_cache" "/var/cache/php/opcache"
    [ ! -f "/etc/php/conf.d/imagick.ini" ] || lk_enable_entry "/etc/php/conf.d/imagick.ini" "extension=imagick" ";"
    [ ! -f "/etc/php/conf.d/memcache.ini" ] || lk_enable_entry "/etc/php/conf.d/memcache.ini" "extension=memcache.so" ";"
    [ ! -f "/etc/php/conf.d/memcached.ini" ] || lk_enable_entry "/etc/php/conf.d/memcached.ini" "extension=memcached.so" ";"
    [ ! -f "/etc/php/conf.d/xdebug.ini" ] || {
        lk_enable_entry "/etc/php/conf.d/xdebug.ini" "zend_extension=xdebug.so" ";"
        mkdir -pm777 "$HOME/.tmp/"{cachegrind,trace}
        PHP_INI_FILE="/etc/php/conf.d/xdebug.ini"
        apply_php_setting "xdebug.remote_enable" "On"
        apply_php_setting "xdebug.remote_autostart" "Off"
        apply_php_setting "xdebug.profiler_enable_trigger" "On"
        apply_php_setting "xdebug.profiler_output_dir" "$HOME/.tmp/cachegrind"
        apply_php_setting "xdebug.profiler_output_name" "callgrind.out.%H.%R.%u"
        apply_php_setting "xdebug.trace_enable_trigger" "On"
        apply_php_setting "xdebug.collect_params" "4"
        apply_php_setting "xdebug.collect_return" "On"
        apply_php_setting "xdebug.trace_output_dir" "$HOME/.tmp/trace"
        apply_php_setting "xdebug.trace_output_name" "trace.%H.%R.%u"
    }
    [ ! -f "/etc/php/php-fpm.conf" ] ||
        {
            PHP_INI_FILE="/etc/php/php-fpm.conf"
            apply_php_setting "emergency_restart_threshold" "10" # restart FPM if 10 children are gone in 60 seconds
            apply_php_setting "emergency_restart_interval" "60"  #
            apply_php_setting "events.mechanism" "epoll"         # don't rely on auto detection
        }
    [ ! -f "/etc/php/php-fpm.d/www.conf" ] ||
        {
            sudo chgrp http "/var/log/httpd" &&
                sudo chmod g+w "/var/log/httpd"
            PHP_INI_FILE="/etc/php/php-fpm.d/www.conf"
            apply_php_setting "pm" "static"             # ondemand can't handle bursts: https://github.com/php/php-src/pull/1308
            apply_php_setting "pm.max_children" "50"    # MUST be >= MaxRequestWorkers in httpd.conf
            apply_php_setting "pm.max_requests" "0"     # don't respawn automatically
            apply_php_setting "rlimit_files" "524288"   # check `ulimit -Hn` and raise for user http in /etc/security/limits.d/ if required
            apply_php_setting "rlimit_core" "unlimited" # as above, but check `ulimit -Hc` instead
            apply_php_setting "pm.status_path" "/status"
            apply_php_setting "ping.path" "/ping"
            apply_php_setting "access.log" '/var/log/httpd/php-fpm-$pool.access.log'
            apply_php_setting "access.format" '"%R - %u %t \"%m %r%Q%q\" %s %f %{mili}d %{kilo}M %C%%"'
            apply_php_setting "catch_workers_output" "yes"
            apply_php_setting "php_admin_value[error_log]" '/var/log/httpd/php-fpm-$pool.error.log'
            apply_php_setting "php_admin_flag[log_errors]" "On"
            apply_php_setting "php_flag[display_errors]" "Off"
            apply_php_setting "php_flag[display_startup_errors]" "Off"
        }
    sudo systemctl enable --now php-fpm || true

    sudo mkdir -p "/srv/http" &&
        sudo chown -c "$USER:" "/srv/http" &&
        mkdir -p "/srv/http/localhost/html" "/srv/http/127.0.0.1" &&
        { [ -e "/srv/http/127.0.0.1/html" ] || ln -s "../localhost/html" "/srv/http/127.0.0.1/html"; } &&
        lk_safe_symlink "$CONFIG_DIR/httpd-vhost-alias.conf" "/etc/httpd/conf/extra/httpd-vhost-alias.conf" &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "Include conf/extra/httpd-vhost-alias.conf" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule alias_module modules/mod_alias.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule dir_module modules/mod_dir.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule headers_module modules/mod_headers.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule info_module modules/mod_info.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule proxy_module modules/mod_proxy.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule rewrite_module modules/mod_rewrite.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule status_module modules/mod_status.so" "# " &&
        lk_enable_entry "/etc/httpd/conf/httpd.conf" "LoadModule vhost_alias_module modules/mod_vhost_alias.so" "# " &&
        sudo usermod --append --groups "http" "$USER" &&
        sudo usermod --append --groups "$(id -gn)" "http" &&
        sudo systemctl enable --now httpd || true

    unset SUDO_OR_NOT

    ! lk_command_exists vim || lk_safe_symlink "$(command -v vim)" "/usr/local/bin/vi" Y
    ! lk_command_exists xfce4-terminal || lk_safe_symlink "$(command -v xfce4-terminal)" "/usr/local/bin/xterm" Y
    SUDO_OR_NOT=1 lk_install_gnu_commands

    exit

}
