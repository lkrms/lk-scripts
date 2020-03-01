#!/bin/bash
# shellcheck disable=SC1090,SC2034,SC2174

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_is_desktop
assert_not_root

function lk_install_aur() (
    export BUILDDIR="/tmp/makepkg" MAKEFLAGS
    MAKEFLAGS="-j$(nproc)" || exit
    ERRORS=()
    mkdir -p "$CACHE_DIR/aur" || exit
    for AUR in "$@"; do
        cd "$CACHE_DIR/aur" || exit
        if [ ! -d "$AUR" ]; then
            lk_console_item "Cloning repo" "https://aur.archlinux.org/$AUR.git"
            git clone "https://aur.archlinux.org/$AUR.git" &&
                cd "$AUR" ||
                exit
        else
            cd "$AUR" && {
                lk_is_false "${LK_UPDATE_AUR:-1}" || {
                    lk_console_item "Updating repo" "https://aur.archlinux.org/$AUR.git"
                    git pull
                }
            } || exit
        fi
        makepkg -si --noconfirm --needed || ERRORS+=("$AUR")
    done
    [ "${#ERRORS[@]}" -eq "0" ] || lk_echo_array "${ERRORS[@]}" | lk_console_list "Failed to install" "AUR package" "AUR packages" "$BOLD$RED"
)

PAC_INSTALL=()
AUR_INSTALL=()

# alis.sh has these covered
PAC_PRE_INSTALLED=(
    linux
    linux-headers
    networkmanager
    xdg-user-dirs

    # probably
    dosfstools
    grub
    intel-media-driver
    intel-ucode
    lightdm
    lightdm-gtk-greeter
    linux-zen
    linux-zen-headers
    mesa
    vulkan-icd-loader
    vulkan-intel
    xfce4
    xfce4-goodies
    xorg-server

    # probably not
    lvm2

    # if needed
    virtualbox-guest-dkms
    virtualbox-guest-modules-arch
    virtualbox-guest-utils
    virtualbox-guest-utils

    # added in lkrms/alis
    b43-fwcutter
    btrfs-progs
    crda
    curl
    dhclient
    dhcpcd
    diffutils
    dmidecode
    dmraid
    dnsmasq
    dosfstools
    ethtool
    exfat-utils
    f2fs-tools
    gnome-initial-setup
    gnu-netcat
    gpm
    gptfdisk
    grub
    hdparm
    ipw2100-fw
    ipw2200-fw
    jfsutils
    lftp
    linux-firmware
    lsb-release
    lvm2
    man-db
    man-pages
    mdadm
    mtools
    nano
    net-tools
    network-manager-applet
    nfs-utils
    nmap
    ntfs-3g
    ntp
    openconnect
    openssh
    openvpn
    parted
    ppp
    pptpclient
    reiserfsprogs
    rsync
    smartmontools
    sudo
    tcpdump
    usb_modeswitch
    usbutils
    vi
    vpnc
    wget
    wireless_tools
    wireless-regdb
    wpa_supplicant
    xfsprogs
    xl2tpd

    # "base"
    bash
    bzip2
    coreutils
    file
    filesystem
    findutils
    gawk
    gcc-libs
    gettext
    glibc
    grep
    gzip
    iproute2
    iputils
    licenses
    pacman
    pciutils
    procps-ng
    psmisc
    sed
    shadow
    systemd
    systemd-sysvcompat
    tar
    util-linux
    xz

    # "base-devel"
    autoconf
    automake
    binutils
    bison
    fakeroot
    file
    findutils
    flex
    gawk
    gcc
    gettext
    grep
    groff
    gzip
    libtool
    m4
    make
    pacman
    patch
    pkgconf
    sed
    sudo
    texinfo
    which
)

# hardware-related
is_virtual || PAC_INSTALL+=(
    hddtemp
    lm_sensors
    powertop
    tlp
    tlp-rdw

    # desktop-only
    blueman
    pulseaudio-bluetooth
)

AUR_INSTALL+=(
    r8152-dkms # common USB / USB-C NIC
)

# essentials
PAC_INSTALL+=(
    gnome-keyring
    gvfs
    gvfs-smb
    libcanberra
    libcanberra-pulse
    pavucontrol
)

AUR_INSTALL+=(
    xfce4-panel-profiles
)

# themes and fonts
PAC_INSTALL+=(
    #
    adapta-gtk-theme
    arc-gtk-theme
    arc-icon-theme
    arc-solid-gtk-theme
    breeze-gtk
    breeze-icons
    materia-gtk-theme

    #
    elementary-icon-theme
    elementary-wallpapers
    gtk-theme-elementary
    sound-theme-elementary

    #
    moka-icon-theme
    papirus-icon-theme

    #
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    noto-fonts-extra
    ttf-dejavu
)

# terminal-based
PAC_INSTALL+=(
    # shells
    bash-completion
    byobu
    ksh
    zsh

    # utilities
    bc
    mediainfo
    p7zip
    pv
    stow
    unison
    unzip
    vim

    # networking
    bridge-utils
    traceroute
    whois

    # monitoring
    atop
    glances
    htop
    iftop
    iotop
    nethogs
    nload
    sysstat

    # system
    hwinfo
    sysfsutils
)

AUR_INSTALL+=(
    vpn-slice
)

# desktop
PAC_INSTALL+=(
    caprine
    catfish
    copyq
    firefox
    flameshot
    galculator
    geany
    gimp
    inkscape
    keepassxc
    libreoffice-fresh
    nextcloud-client
    qpdfview
    remmina
    scribus
    speedcrunch
    thunderbird
    transmission-cli
    transmission-gtk
    trash-cli

    # PDF
    ghostscript  # PDF/PostScript processor
    mupdf-tools  # PDF manipulation tools
    pandoc       # text conversion tool (e.g. Markdown to PDF)
    poppler      # PDF tools like pdfimages
    pstoedit     # converts PDF/PostScript to vector formats
    texlive-core # required for PDF output from pandoc

    # search (Recoll)
    antiword            # Word
    aspell-en           # English stemming
    catdoc              # Excel, Powerpoint
    perl-image-exiftool # EXIF metadata
    python-lxml         # spreadsheets
    recoll

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
    x11vnc

    # automation
    sxhkd
    wmctrl
    xautomation
    xclip
    xdotool
)

AUR_INSTALL+=(
    espanso
    ghostwriter
    google-chrome
    skypeforlinux-stable-bin
    spotify
    teams
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

    # these need to be installed in this order
    gconf
    gnome-python
    gnome-python-desktop # i.e. python2-wnck
    python2-xlib
    quicktile-git
)

# development
PAC_INSTALL+=(
    code
    dbeaver
    tidy

    #
    git
    meld

    #
    jre-openjdk

    #
    nodejs
    npm
    yarn

    #
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
    wp-cli

    #
    mysql-python
    python
    python-dateutil
    python-pip
    python-requests
    python2

    #
    shellcheck

    #
    lua-penlight
    lua51
)

AUR_INSTALL+=(
    sublime-text-dev

    #
    git-cola
    sublime-merge
)

# development services
PAC_INSTALL+=(
    apache
    mariadb
    php-fpm
)

# libvirt
PAC_INSTALL+=(
    dnsmasq
    ebtables
    libvirt
    qemu
    virt-manager
)

! offer_sudo_password_bypass ||
    {
        lk_console_message "Disabling password-based login as root"
        sudo passwd -l root
    }

sudo pacman -Sy --needed "${PAC_INSTALL[@]}"

# otherwise makepkg fails with "unknown public key" errors
gpg --list-keys >/dev/null
[ -e "$HOME/.gnupg/gpg.conf" ] || {
    touch "$HOME/.gnupg/gpg.conf" &&
        chmod 600 "$HOME/.gnupg/gpg.conf"
}
[ ! -e "/etc/pacman.d/gnupg/pubring.gpg" ] ||
    grep -Fq 'keyring /etc/pacman.d/gnupg/pubring.gpg' "$HOME/.gnupg/gpg.conf" || {
    GPG_CONF="$(cat "$HOME/.gnupg/gpg.conf")" && {
        [ -z "$GPG_CONF" ] || echo "$GPG_CONF"
        echo 'keyring /etc/pacman.d/gnupg/pubring.gpg'
    } >"$HOME/.gnupg/gpg.conf"
}

lk_install_aur "${AUR_INSTALL[@]}"

sudo systemctl enable --now sshd.service

! lk_command_exists vim || lk_safe_symlink "$(command -v vim)" "/usr/local/bin/vi" Y

xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Arc-Dark-solid"
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark"
xfconf-query -c xsettings -p /Net/SoundThemeName -n -t string -s "elementary"
xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Arc-Dark-solid"
