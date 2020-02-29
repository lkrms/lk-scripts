#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

function lk_install_aur() {
    local TEMP_DIR
    TEMP_DIR="$(lk_mktemp_dir)" || return
    lk_delete_on_exit "$TEMP_DIR"
    (
        cd "$TEMP_DIR" &&
            git clone "https://aur.archlinux.org/$1.git" &&
            cd "$1" &&
            makepkg -si
    )
}

INSTALL=()

# sound-related
INSTALL+=(
    blueman
    libcanberra
    libcanberra-pulse
    pavucontrol
    pulseaudio-bluetooth
)

# themes and fonts
INSTALL+=(
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

# terminal
INSTALL+=(
    unison
    vim
)

# desktop
#   ghostwriter
#   spotify
#   typora
INSTALL+=(
    clementine
    firefox
    flameshot
    geany
    guake
    keepassxc
    libreoffice-fresh
    nextcloud-client
    recoll
    speedcrunch
    thunderbird
)

# development
#   git-cola
#   smerge
INSTALL+=(
    code
    dbeaver
    git
    java-openjdk
)

# libvirt
INSTALL+=(
    bridge-utils
    dnsmasq
    ebtables
    libvirt
    qemu
    virt-manager
)

sudo pacman -Sy --needed "${INSTALL[@]}"

xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Arc-Dark-solid"
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark"
xfconf-query -c xsettings -p /Net/SoundThemeName -n -t string -s "elementary"
xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Arc-Dark-solid"

lk_command_exists yay || lk_install_aur yay
