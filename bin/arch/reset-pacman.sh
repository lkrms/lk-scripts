#!/bin/bash
# shellcheck disable=SC1090,SC2046,SC2207

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

assert_not_root

# mark everything as a dependency
! EXPLICIT=($(pacman -Qeq)) ||
    [ "${#EXPLICIT[@]}" -eq "0" ] ||
    sudo pacman -D --asdeps "${EXPLICIT[@]}"

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
        sudo pacman -Sy >&2
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

! is_qemu ||
    PACMAN_PACKAGES+=(
        qemu-guest-agent
        spice-vdagent
    )

AUR_PACKAGES=(
    yay
    mugshot
    xfce4-panel-profiles
    xiccd
)

# mark (installed) bootstrap packages as explicitly installed
INSTALLED=($(comm -12 <(pacman -Qdq | sort | uniq) <(lk_echo_array "${PACMAN_PACKAGES[@]}" "${AUR_PACKAGES[@]}" | sort | uniq)))
[ "${#INSTALLED[@]}" -eq "0" ] ||
    sudo pacman -D --asexplicit "${INSTALLED[@]}"

MISSING_PAC=($(comm -13 <(pacman -Qeq | sort | uniq) <(lk_echo_array "${PACMAN_PACKAGES[@]}" | sort | uniq)))
MISSING_AUR=($(comm -13 <(pacman -Qeq | sort | uniq) <(lk_echo_array "${AUR_PACKAGES[@]}" | sort | uniq)))
MISSING=(${MISSING_PAC[@]+"${MISSING_PAC[@]}"} ${MISSING_AUR[@]+"${MISSING_AUR[@]}"})
[ "${#MISSING[@]}" -eq "0" ] ||
    ! get_confirmation "Install missing bootstrap packages?" ||
    {
        [ "${#MISSING_PAC[@]}" -eq "0" ] ||
            sudo pacman -Sy "${MISSING_PAC[@]}"

        [ "${#MISSING_AUR[@]}" -eq "0" ] ||
            { ! lk_command_exists yay && lk_warn "yay command missing"; } ||
            yay -Sy --aur "${MISSING_AUR[@]}"
    }
