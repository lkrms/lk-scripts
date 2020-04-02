#!/bin/bash
# shellcheck disable=SC1090,SC2046,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_not_root

# mark everything as a dependency
sudo pacman -D --asdeps $(pacman -Qeq)

# TODO: populate from bootstrap.sh
PACMAN_PACKAGES=(
    lynx

    # basics
    galculator
    geany
    gimp
    keepassxc
    libreoffice-fresh
    qpdfview
    samba
    speedcrunch

    # browsers
    chromium
    falkon
    firefox

    # multimedia
    libdvdcss
    libdvdnav
    libvpx
    vlc

    # remote desktop
    x11vnc

    #
    adapta-gtk-theme
    arc-gtk-theme
    arc-icon-theme
    arc-solid-gtk-theme
    breeze-gtk
    breeze-icons

    #
    gtk-engine-murrine
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
    ttf-inconsolata
    ttf-jetbrains-mono
    ttf-lato
    ttf-opensans
    ttf-roboto
    ttf-roboto-mono
    ttf-ubuntu-font-family

    #
    archlinux-wallpaper

    # bare minimum
    base
    linux
    mkinitcpio

    # boot
    grub
    efibootmgr

    # multi-boot
    os-prober
    ntfs-3g

    # bootstrap.sh dependencies
    sudo
    networkmanager
    openssh
    ntp

    # basics
    bash-completion
    byobu
    curl
    diffutils
    dmidecode
    git
    lftp
    nano
    net-tools
    nmap
    openbsd-netcat
    rsync
    tcpdump
    traceroute
    vim
    wget

    # == UNNECESSARY ON DISPOSABLE SERVERS
    #
    man-db
    man-pages

    # filesystems
    btrfs-progs
    dosfstools
    f2fs-tools
    jfsutils
    reiserfsprogs
    xfsprogs
    nfs-utils

    #
    xdg-user-dirs
    lightdm
    lightdm-gtk-greeter
    xorg-server
    xorg-xrandr

    #
    cups
    flameshot
    gnome-keyring
    gvfs
    gvfs-smb
    network-manager-applet
    seahorse
    zenity

    #
    $(
        pacman -Sy >&2
        pacman -Sgq xfce4 xfce4-goodies | grep -Fxv xfce4-screensaver
    )
    catfish
    engrampa
    pavucontrol
    libcanberra
    libcanberra-pulse
    plank

    # xfce4-screensaver replacement
    xsecurelock
    xss-lock

    #
    pulseaudio-alsa

    #
    qemu-guest-agent
    spice-vdagent

    #
    linux-firmware
    linux-headers

    #
    hddtemp
    lm_sensors
    powertop
    tlp
    tlp-rdw

    #
    gptfdisk
    lvm2
    mdadm
    parted

    #
    ethtool
    hdparm
    nvme-cli
    smartmontools
    usb_modeswitch
    usbutils
    wpa_supplicant

    #
    b43-fwcutter
    ipw2100-fw
    ipw2200-fw

    #
    intel-ucode

    #
    mesa
    libvdpau-va-gl
    intel-media-driver
    libva-intel-driver

    #
    blueman
    pulseaudio-bluetooth

    #
    $(pacman -Sgq base-devel)
    go
)

AUR_PACKAGES=(
    yay
    mugshot
    xfce4-panel-profiles
    xiccd
)

# mark bootstrap packages as explicitly installed
sudo pacman -D --asexplicit $(comm -12 <(pacman -Qdq | sort | uniq) <(lk_echo_array "${PACMAN_PACKAGES[@]}" "${AUR_PACKAGES[@]}" | sort | uniq))
