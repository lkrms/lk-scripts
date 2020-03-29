#!/bin/bash
# shellcheck disable=SC2015,SC2206,SC2207

# Usage:
#   1. boot from an Arch Linux live CD
#   2. wget https://lkr.ms/bootstrap
#   3. bash bootstrap

set -euo pipefail

PING_HOSTNAME="one.one.one.one" # see https://blog.cloudflare.com/dns-resolver-1-1-1-1/
NTP_SERVER="ntp.lkrms.org"      #
MOUNT_OPTIONS="defaults"        # add ",noatime" if needed
TIMEZONE="Australia/Sydney"     # see /usr/share/zoneinfo
LOCALES=("en_AU" "en_GB")       # UTF-8 is enforced
LANGUAGE="en_AU:en_GB:en"
MIRROR="http://archlinux.mirror.lkrms.org/archlinux/\$repo/os/\$arch"
PACMAN_PACKAGES=()
PACMAN_DESKTOP_PACKAGES=()

function die() {
    local EXIT_STATUS="$?"
    [ "$EXIT_STATUS" -ne "0" ] || EXIT_STATUS="1"
    [ "$#" -eq "0" ] || echo "$(basename "$0"): $BOLD$RED$1$RESET" >&2
    exit "$EXIT_STATUS"
}

function usage() {
    {
        echo "$BOLD${CYAN}Usage:$RESET
  $(basename "$0") ${YELLOW}root_partition boot_partition$RESET hostname username
  $(basename "$0") ${YELLOW}install_disk$RESET hostname username

$BOLD${CYAN}Current block devices:$RESET"
        lsblk --output "NAME,RM,RO,SIZE,TYPE,FSTYPE,MOUNTPOINT" --paths
    } >&2
    die
}

function safe_tput() {
    ! tput "$@" >/dev/null 2>&1 ||
        tput "$@"
}

function message() {
    echo $'\n'"$BOLD$CYAN:: $1$RESET" >&2
}

function confirm() {
    local YN
    read -rp $'\n'"$BOLD$1$RESET [y/n] " YN
    [[ "$YN" =~ ^[yY]$ ]]
}

function get_secret() {
    local SECRET
    read -rsp $'\n'"$BOLD$YELLOW$1$RESET " SECRET
    echo "$SECRET"
}

function is_dryrun() {
    [ "${DRYRUN:-1}" -eq "1" ]
}

function maybe_dryrun() {
    if is_dryrun; then
        echo "$CYAN[DRY RUN]$RESET skipped: $*" >&2
    else
        "$@"
    fi
}

function _lsblk() {
    lsblk --list --noheadings --output "$@"
}

function check_devices() {
    local COLUMN="${COLUMN:-TYPE}" MATCH="$1" LIST
    shift
    LIST="$(_lsblk "$COLUMN" --nodeps "$@")" &&
        echo "$LIST" | grep -Fx "$MATCH" >/dev/null &&
        ! echo "$LIST" | grep -Fxv "$MATCH" >/dev/null
}

function before_install() {
    message "checking network connection..."
    ping -c 1 "${PING_HOSTNAME:-one.one.one.one}" || die "no network"

    message "updating system clock..."
    configure_ntp "/etc/ntp.conf"
    maybe_dryrun timedatectl set-ntp true
}

function in_target() {
    maybe_dryrun arch-chroot /mnt "$@"
}

function configure_ntp() {
    [ -z "${NTP_SERVER:-}" ] || {
        [ -e "$1.orig" ] || maybe_dryrun cp -pv "$1" "$1.orig"
        maybe_dryrun sed -Ei 's/^(server|pool)\b/#&/' "$1"
        is_dryrun || echo "server $NTP_SERVER iburst" >>"$1"
    }
}

function configure_pacman() {
    [ -e "$1.orig" ] || maybe_dryrun cp -pv "$1" "$1.orig"
    maybe_dryrun sed -Ei 's/^#\s*(Color|TotalDownload)\s*$/\1/' "$1"
}

# by default, DRYRUN=1 unless running as root
[ -n "${DRYRUN:-}" ] || {
    DRYRUN=0
    [ "$EUID" -eq "0" ] || DRYRUN=1
}

PACMAN_PACKAGES=(
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
    ${PACMAN_PACKAGES[@]+"${PACMAN_PACKAGES[@]}"}
)

PACMAN_DESKTOP_PACKAGES=(
    xdg-user-dirs
    lightdm
    lightdm-gtk-greeter
    xorg-server
    xorg-xrandr

    #
    cups
    gnome-keyring
    gvfs
    gvfs-smb
    network-manager-applet
    zenity

    #
    xfce4
    $(
        # xfce4-screensaver is buggy and insecure, and it autostarts
        # by default, so remove it from xfce4-goodies
        { is_dryrun || [ "$#" -eq "0" ]; } &&
            echo "xfce4-goodies" ||
            {
                pacman -Sy >&2
                pacman -Sgq "xfce4-goodies" | grep -Fxv "xfce4-screensaver"
            }
    )
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
    ${PACMAN_DESKTOP_PACKAGES[@]+"${PACMAN_DESKTOP_PACKAGES[@]}"}
)

grep -Eq '^flags\s*:.*\shypervisor(\s|$)' /proc/cpuinfo || {
    PACMAN_PACKAGES+=(
        linux-firmware
        linux-headers

        #
        hddtemp
        lm_sensors
        tlp
        tlp-rdw

        #
        gptfdisk # provides sgdisk
        lvm2     #
        mdadm    # software RAID
        parted

        #
        ethtool
        hdparm
        smartmontools
        usb_modeswitch
        usbutils
        wpa_supplicant

        #
        b43-fwcutter
        ipw2100-fw
        ipw2200-fw
    )
    ! grep -Eq '^vendor_id\s*:\s+GenuineIntel$' /proc/cpuinfo ||
        PACMAN_PACKAGES+=(intel-ucode)
    ! grep -Eq '^vendor_id\s*:\s+AuthenticAMD$' /proc/cpuinfo ||
        PACMAN_PACKAGES+=(amd-ucode)

    PACMAN_DESKTOP_PACKAGES+=(
        mesa
        libvdpau-va-gl
        intel-media-driver # TODO: detect intel graphics first
        libva-intel-driver

        #
        blueman
        pulseaudio-bluetooth
    )
}

RED="$(safe_tput setaf 1)"
GREEN="$(safe_tput setaf 2)"
YELLOW="$(safe_tput setaf 3)"
CYAN="$(safe_tput setaf 6)"
BOLD="$(safe_tput bold)"
RESET="$(safe_tput sgr0)"

[ -d "/sys/firmware/efi/efivars" ] || die "please reboot in UEFI mode"

# in case we're starting over
[ ! -d "/mnt/boot" ] || {
    maybe_dryrun umount /mnt/boot
    maybe_dryrun umount /mnt
} || die

case "$#" in
3)
    [ -e "$1" ] &&
        check_devices disk "$1" ||
        usage

    before_install

    confirm "Repartition $1? ALL DATA WILL BE LOST." || die

    message "Partitioning $1..."
    maybe_dryrun parted --script "$1" \
        mklabel gpt \
        mkpart fat32 2048s 260MiB \
        mkpart ext4 260MiB 100% \
        set 1 boot on &&
        maybe_dryrun partprobe "$1" &&
        PARTITIONS=($(_lsblk "TYPE,NAME" --paths "$1" | grep -Po '(?<=^part ).*')) &&
        [ "${#PARTITIONS[@]}" -eq "2" ] &&
        ROOT_PARTITION="${PARTITIONS[1]}" &&
        BOOT_PARTITION="${PARTITIONS[0]}" &&
        maybe_dryrun wipefs -a "$ROOT_PARTITION" &&
        maybe_dryrun wipefs -a "$BOOT_PARTITION" ||
        is_dryrun

    REPARTITIONED=1
    TARGET_HOSTNAME="$2"
    TARGET_USERNAME="$3"
    ;;

4)
    [ -e "$1" ] &&
        [ -e "$2" ] &&
        check_devices part "$1" "$2" ||
        usage

    before_install

    REPARTITIONED=0
    ROOT_PARTITION="$1"
    BOOT_PARTITION="$2"
    TARGET_HOSTNAME="$3"
    TARGET_USERNAME="$4"
    ;;

*)
    usage
    ;;

esac

TARGET_PASSWORD="${TARGET_PASSWORD:-}"
[ -n "$TARGET_PASSWORD" ] || {
    while :; do
        TARGET_PASSWORD="$(get_secret "Password for $TARGET_USERNAME:")" &&
            CONFIRM_PASSWORD="$(get_secret "Password for $TARGET_USERNAME (again):")"
        echo
        [ -n "$TARGET_PASSWORD" ] &&
            [ "$TARGET_PASSWORD" = "$CONFIRM_PASSWORD" ] &&
            break ||
            echo -n "$BOLD$RED:: password missing or mismatched$RESET" >&2
    done
}

confirm "Install Xfce?" || {
    PACMAN_DESKTOP_PACKAGES=()
}

message "probing partitions..."
maybe_dryrun partprobe

ROOT_PARTITION_TYPE="$(_lsblk FSTYPE "$ROOT_PARTITION")" || die "no block device at $ROOT_PARTITION"
BOOT_PARTITION_TYPE="$(_lsblk FSTYPE "$BOOT_PARTITION")" || die "no block device at $BOOT_PARTITION"

if [ -z "$BOOT_PARTITION_TYPE" ] || {
    [ "$BOOT_PARTITION_TYPE" = "vfat" ] &&
        ! confirm "$BOOT_PARTITION already has a vfat filesystem. Leave it as-is?"
}; then

    { [ "$REPARTITIONED" -eq "1" ] || confirm "OK to format $BOOT_PARTITION as FAT32?"; } && {
        message "formatting $BOOT_PARTITION..."
        maybe_dryrun mkfs.fat -n ESP -F 32 "$BOOT_PARTITION"
    } || die

elif [ "$BOOT_PARTITION_TYPE" != "vfat" ]; then

    die "unexpected filesystem at $BOOT_PARTITION: $BOOT_PARTITION_TYPE"

fi

[ -z "$ROOT_PARTITION_TYPE" ] || message "WARNING: unexpected filesystem at $ROOT_PARTITION: $ROOT_PARTITION_TYPE"

{ [ "$REPARTITIONED" -eq "1" ] || confirm "OK to format $ROOT_PARTITION as ext4?"; } && {
    message "formatting $ROOT_PARTITION..."
    maybe_dryrun mkfs.ext4 -L root "$ROOT_PARTITION"
} || die

message "mounting partitions..."
maybe_dryrun mount -o "${MOUNT_OPTIONS:-defaults}" "$ROOT_PARTITION" /mnt &&
    maybe_dryrun mkdir /mnt/boot &&
    maybe_dryrun mount -o "${MOUNT_OPTIONS:-defaults}" "$BOOT_PARTITION" /mnt/boot || die

message "configuring pacman..."
configure_pacman "/etc/pacman.conf"
[ -z "$MIRROR" ] ||
    is_dryrun ||
    echo "Server=$MIRROR" >/etc/pacman.d/mirrorlist # pacstrap copies this to the new system

message "installing system..."
maybe_dryrun pacstrap -i /mnt "${PACMAN_PACKAGES[@]}" ${PACMAN_DESKTOP_PACKAGES[@]+"${PACMAN_DESKTOP_PACKAGES[@]}"}

message "configuring system..."

LOCALES=(${LOCALES[@]+"${LOCALES[@]}"} "en_US")
for l in $(printf '%s\n' "${LOCALES[@]}" | sed 's/\..*$//' | sort | uniq); do
    maybe_dryrun sed -Ei "s/^#($l\\.UTF-8\\s+UTF-8)/\1/" "/mnt/etc/locale.gen"
done

is_dryrun || {
    genfstab -U /mnt >>/mnt/etc/fstab
    echo "%wheel ALL=(ALL) ALL" >"/mnt/etc/sudoers.d/90-wheel"
    {
        echo "LANG=${LOCALES[0]}.UTF-8"
        [ -z "${LANGUAGE:-}" ] || echo "LANGUAGE=$LANGUAGE"
    } >"/mnt/etc/locale.conf"
    echo "$TARGET_HOSTNAME" >"/mnt/etc/hostname"
    cat <<EOF >"/mnt/etc/hosts"
127.0.0.1 localhost
::1 localhost
127.0.1.1 $TARGET_HOSTNAME
EOF
}

in_target locale-gen

maybe_dryrun ln -sfv "/usr/share/zoneinfo/${TIMEZONE:-UTC}" "/mnt/etc/localtime"
in_target hwclock --systohc

in_target useradd -m "$TARGET_USERNAME" -G adm,wheel -s /bin/bash &&
    echo -e "$TARGET_PASSWORD\n$TARGET_PASSWORD" | in_target passwd "$TARGET_USERNAME" &&
    in_target passwd -l root

configure_pacman "/mnt/etc/pacman.conf"

message "enabling ntpd..."
configure_ntp "/mnt/etc/ntp.conf" &&
    in_target systemctl enable ntpd.service

! _lsblk "DISC-GRAN,DISC-MAX" --nodeps "$ROOT_PARTITION" "$BOOT_PARTITION" | grep -Ev '^\s*0B\s+0B\s*$' >/dev/null || {
    message "enabling fstrim..."
    in_target systemctl enable fstrim.timer # weekly
}

message "installing boot loader..."
in_target grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB &&
    in_target grub-mkconfig -o /boot/grub/grub.cfg

echo "$BOLD${GREEN}Bootstrap complete. Reboot at your leisure.$RESET" >&2
