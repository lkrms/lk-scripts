#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" || SCRIPT_PATH="$(python -c 'import os,sys;print os.path.realpath(sys.argv[1])' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

. "$SCRIPT_DIR/../../bash/common"

function lk_install_aur() (
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
    [ "${#ERRORS[@]}" -eq "0" ] || lk_echo_array "${ERRORS[@]}" || lk_console_list "Failed to install" "AUR package" "AUR packages" "$BOLD$RED"
)

PAC_INSTALL=()
AUR_INSTALL=()

# hardware-related
is_virtual || PAC_INSTALL+=(
    blueman
    pulseaudio-bluetooth
    tlp
    tlp-rdw
)

# essentials
PAC_INSTALL+=(
    gvfs
    gvfs-smb
    libcanberra
    libcanberra-pulse
    pavucontrol
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
    p7zip
    trash-cli
    unison
    vim
)

# desktop
PAC_INSTALL+=(
    audacity
    clementine
    copyq
    displaycal
    firefox
    flameshot
    geany
    guake
    handbrake
    handbrake-cli
    inkscape
    keepassxc
    libreoffice-fresh
    nextcloud-client
    recoll
    scribus
    speedcrunch
    thunderbird
)

AUR_INSTALL+=(
    espanso
    ghostwriter
    google-chrome
    makemkv
    skypeforlinux-stable-bin
    spotify
    teams
    typora
)

# development
PAC_INSTALL+=(
    code
    dbeaver
    git
    jre-openjdk
)

AUR_INSTALL+=(
    git-cola
    sublime-merge
    sublime-text-dev
)

# libvirt
PAC_INSTALL+=(
    bridge-utils
    dnsmasq
    ebtables
    libvirt
    qemu
    virt-manager
)

offer_sudo_password_bypass

sudo pacman -Sy --needed "${PAC_INSTALL[@]}"

lk_install_aur "${AUR_INSTALL[@]}"

sudo systemctl enable --now sshd.service

xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Arc-Dark-solid"
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark"
xfconf-query -c xsettings -p /Net/SoundThemeName -n -t string -s "elementary"
xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "Arc-Dark-solid"
